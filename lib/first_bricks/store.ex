defmodule FirstBricks.Store do
  @moduledoc "Écriture sérialisée et synchronisée sur disque. Une seule instance par volume."
  use GenServer
  alias FirstBricks.BSX
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def state, do: GenServer.call(__MODULE__, :state)

  def import(kind, name, xml) when kind in ["cfb", "ufb", "vendor"] do
    with {:ok, rows} <- BSX.parse(xml) do
      if kind == "vendor" and rows == [],
        do: {:error, "Réception sans pièce."},
        else: GenServer.call(__MODULE__, {:import, kind, name, xml, rows})
    end
  end

  def allocate(id, revision, cfb, ufb),
    do: GenServer.call(__MODULE__, {:allocate, id, revision, cfb, ufb})

  def stock(state, site, row) do
    case List.first(state.inventories[site]) do
      nil ->
        :not_imported

      inventory ->
        case Enum.find(inventory.rows, &(BSX.key(&1) == BSX.key(row))) do
          nil -> :absent
          found -> {:present, found["Qty"]}
        end
    end
  end

  def export(reception, site) when site in ["cfb", "ufb"] do
    reception.rows
    |> Enum.with_index()
    |> Enum.map(fn {row, i} ->
      Map.put(row, "Qty", reception.allocations[Integer.to_string(i)][site])
    end)
    |> BSX.export()
  end

  def init(_) do
    dir = Application.fetch_env!(:first_bricks, :data_dir)
    File.mkdir_p!(dir)

    {:ok, :first_bricks_data} =
      :dets.open_file(:first_bricks_data,
        file: String.to_charlist(Path.join(dir, "first_bricks.dets")),
        type: :set
      )

    state =
      case :dets.lookup(:first_bricks_data, :state) do
        [] -> %{inventories: %{"cfb" => [], "ufb" => []}, receptions: %{}}
        [{:state, saved}] -> saved
      end

    {:ok, state}
  end

  def handle_call(:state, _, state), do: {:reply, state, state}

  def handle_call({:import, kind, name, xml, rows}, _, state) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

    document = %{
      id: id,
      name: Path.basename(name),
      xml: xml,
      rows: rows,
      imported_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {next, response} =
      if kind == "vendor" do
        allocations =
          rows
          |> Enum.with_index()
          |> Map.new(fn {_, i} -> {Integer.to_string(i), %{"cfb" => 0, "ufb" => 0}} end)

        reception = Map.merge(document, %{revision: 0, allocations: allocations})
        {put_in(state, [:receptions, id], reception), {:ok, id}}
      else
        {update_in(state, [:inventories, kind], &[document | &1]), {:ok, nil}}
      end

    persist(next)
    {:reply, response, next}
  end

  def handle_call({:allocate, id, revision, cfb, ufb}, _, state) do
    result =
      with {:ok, reception} <- Map.fetch(state.receptions, id),
           true <- revision == Integer.to_string(reception.revision) do
        try do
          expected =
            reception.rows
            |> Enum.with_index()
            |> Enum.map(fn {_, i} -> Integer.to_string(i) end)
            |> Enum.sort()

          if not is_map(cfb) or not is_map(ufb) or Enum.sort(Map.keys(cfb)) != expected or
               Enum.sort(Map.keys(ufb)) != expected,
             do: raise("Toutes les lignes doivent être renseignées.")

          allocations =
            reception.rows
            |> Enum.with_index()
            |> Map.new(fn {row, i} ->
              key = Integer.to_string(i)
              a = BSX.integer!(cfb[key])
              b = BSX.integer!(ufb[key])

              if a + b > row["Qty"],
                do: raise("Ligne #{i + 1} : attribution supérieure à la quantité reçue.")

              {key, %{"cfb" => a, "ufb" => b}}
            end)

          {:ok, %{reception | allocations: allocations, revision: reception.revision + 1}}
        rescue
          e in RuntimeError -> {:error, Exception.message(e)}
          _ -> {:error, "Attributions invalides."}
        end
      else
        :error -> {:error, "Réception introuvable."}
        false -> {:error, "Cette réception a été modifiée. Rechargez la page avant de réessayer."}
      end

    case result do
      {:ok, reception} ->
        next = put_in(state, [:receptions, id], reception)
        persist(next)
        {:reply, :ok, next}

      error ->
        {:reply, error, state}
    end
  end

  defp persist(state) do
    :ok = :dets.insert(:first_bricks_data, {:state, state})
    :ok = :dets.sync(:first_bricks_data)
  end

  def terminate(_, _), do: :dets.close(:first_bricks_data)
end
