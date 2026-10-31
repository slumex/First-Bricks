defmodule FirstBricks.Allocation do
  @moduledoc "Proposition sans sauvegarde, à partir des derniers inventaires importés."
  alias FirstBricks.BSX

  def suggest(state, reception) do
    with [cfb | _] <- state.inventories["cfb"],
         [ufb | _] <- state.inventories["ufb"] do
      cfb_stock = index(cfb.rows)
      ufb_stock = index(ufb.rows)

      proposal =
        reception.rows
        |> Enum.with_index()
        |> Enum.reduce(%{"cfb" => %{}, "ufb" => %{}}, fn {row, i}, acc ->
          key = BSX.key(row)

          destination =
            if Map.get(cfb_stock, key, 0) <= Map.get(ufb_stock, key, 0), do: "cfb", else: "ufb"

          line = Integer.to_string(i)

          Enum.reduce(["cfb", "ufb"], acc, fn site, result ->
            put_in(
              result,
              [site, line],
              Integer.to_string(if(site == destination, do: row["Qty"], else: 0))
            )
          end)
        end)

      {:ok, proposal}
    else
      _ ->
        {:error,
         "Importez les inventaires CFB et UFB avant d’attribuer automatiquement les stocks."}
    end
  end

  defp index(rows), do: Map.new(rows, &{BSX.key(&1), &1["Qty"]})
end
