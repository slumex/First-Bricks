defmodule FirstBricks.BSX do
  @moduledoc "Sous-ensemble BrickStore XML strict; aucune résolution d'entité externe."
  @fields ~w(ItemID ItemTypeID ColorID Condition ItemName ColorName Price Comments Remarks)
  def parse(xml) when is_binary(xml) do
    cond do
      byte_size(xml) > 5_000_000 ->
        {:error, "Fichier limité à 5 Mo."}

      not String.valid?(xml) ->
        {:error, "Le fichier doit être encodé en UTF-8."}

      Regex.match?(~r/<!DOCTYPE|<!ENTITY/i, xml) ->
        {:error, "Les DTD et entités XML sont interdites."}

      true ->
        decode(xml)
    end
  end

  defp decode(xml) do
    try do
      {:ok, parsed, rest} =
        :xmerl_sax_parser.stream(xml,
          event_fun: &event/3,
          event_state: %{stack: [], rows: [], current: %{}, text: [], inventories: 0, root: false}
        )

      if String.trim(to_string(rest)) != "", do: raise("Données après le document XML")

      if not parsed.root or parsed.inventories != 1,
        do: raise("Structure attendue : BrickStoreXML/Inventory")

      rows =
        Enum.map(Enum.reverse(parsed.rows), fn node ->
          values = Map.new(@fields, &{&1, Map.get(node, &1, "")})
          qty = integer!(Map.get(node, "Qty", ""))

          Enum.each(~w(ItemID ItemTypeID ColorID Condition), fn field ->
            if values[field] == "", do: raise("Champ obligatoire : #{field}")
          end)

          if values["Condition"] not in ["N", "U"], do: raise("État attendu : N ou U")
          if values["ItemTypeID"] not in ~w(P M S B G I O C), do: raise("Type de pièce inconnu")
          if not Regex.match?(~r/^\d+$/, values["ColorID"]), do: raise("Couleur invalide")
          Map.put(values, "Qty", qty)
        end)

      {:ok,
       rows
       |> Enum.group_by(&key/1)
       |> Enum.map(fn {_key, group} ->
         Map.put(hd(group), "Qty", Enum.sum(Enum.map(group, & &1["Qty"])))
       end)
       |> Enum.sort_by(&key/1)}
    rescue
      e in RuntimeError -> {:error, Exception.message(e)}
      _ -> {:error, "XML BSX invalide."}
    catch
      :exit, _ -> {:error, "XML BSX invalide."}
    end
  end

  # SAX conserve les noms XML en chaînes et n'internne pas de tags fournis en atomes.
  defp event({:startElement, _uri, local, _prefix, _attrs}, _location, state) do
    name = to_string(local)

    cond do
      state.stack == [] and name != "BrickStoreXML" ->
        raise("Racine BSX invalide")

      state.stack == [] ->
        %{state | stack: [name], root: true}

      state.stack == ["BrickStoreXML"] and name == "Inventory" ->
        %{state | stack: [name | state.stack], inventories: state.inventories + 1}

      state.stack == ["Inventory", "BrickStoreXML"] and name == "Item" ->
        %{state | stack: [name | state.stack], current: %{}}

      true ->
        %{state | stack: [name | state.stack], text: []}
    end
  end

  defp event(
         {:characters, chars},
         _location,
         %{stack: [field, "Item", "Inventory", "BrickStoreXML"]} = state
       )
       when field in @fields or field == "Qty" do
    %{state | text: [to_string(chars) | state.text]}
  end

  defp event({:endElement, _uri, local, _prefix}, _location, state) do
    name = to_string(local)

    next =
      case state.stack do
        ["Item", "Inventory", "BrickStoreXML"] ->
          %{state | rows: [state.current | state.rows]}

        [field, "Item", "Inventory", "BrickStoreXML"] when field in @fields or field == "Qty" ->
          if Map.has_key?(state.current, field), do: raise("Champ dupliqué : #{field}")
          value = state.text |> Enum.reverse() |> Enum.join() |> String.trim()
          %{state | current: Map.put(state.current, field, value), text: []}

        _ ->
          state
      end

    if hd(next.stack) != name, do: raise("XML invalide")
    %{next | stack: tl(next.stack)}
  end

  defp event(_, _, state), do: state

  def integer!(value) do
    case Integer.parse(value) do
      {n, ""} when n >= 0 and n <= 2_147_483_647 -> n
      _ -> raise "Quantité entière positive ou nulle attendue."
    end
  end

  def key(row), do: Enum.map(~w(ItemTypeID ItemID ColorID Condition), &row[&1])

  def escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def export(rows) do
    items =
      Enum.filter(rows, &(&1["Qty"] > 0))
      |> Enum.map_join("\n", fn row ->
        "<Item>" <>
          Enum.map_join(@fields ++ ["Qty"], fn field ->
            "<#{field}>#{escape(row[field] || "")}</#{field}>"
          end) <> "</Item>"
      end)

    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<BrickStoreXML><Inventory>\n#{items}\n</Inventory></BrickStoreXML>\n"
  end
end
