defmodule FirstBricks.AllocationTest do
  use ExUnit.Case, async: true
  alias FirstBricks.Allocation

  defp row(qty, condition \\ "N"),
    do: %{
      "ItemID" => "3001",
      "ItemTypeID" => "P",
      "ColorID" => "5",
      "Condition" => condition,
      "Qty" => qty
    }

  defp state(cfb, ufb), do: %{inventories: %{"cfb" => [%{rows: cfb}], "ufb" => [%{rows: ufb}]}}

  test "quantité entière au stock inférieur, priorité CFB aux égalités et à zéro" do
    for {cfb, ufb, expected} <- [{1, 8, "cfb"}, {9, 2, "ufb"}, {0, 0, "cfb"}, {4, 4, "cfb"}] do
      assert {:ok, suggestion} =
               Allocation.suggest(state([row(cfb)], [row(ufb)]), %{rows: [row(7)]})

      assert suggestion[expected]["0"] == "7"

      assert String.to_integer(suggestion["cfb"]["0"]) + String.to_integer(suggestion["ufb"]["0"]) ==
               7
    end
  end

  test "lots absents évalués à zéro, état et type restent distincts" do
    assert {:ok, suggestion} =
             Allocation.suggest(state([row(9, "U")], [row(3)]), %{rows: [row(6)]})

    assert suggestion == %{"cfb" => %{"0" => "6"}, "ufb" => %{"0" => "0"}}
    assert {:ok, suggestion} = Allocation.suggest(state([row(9)], []), %{rows: [row(6)]})
    assert suggestion["ufb"]["0"] == "6"

    for field <- ["ItemID", "ItemTypeID", "ColorID"] do
      assert {:ok, suggestion} =
               Allocation.suggest(state([Map.put(row(9), field, "other")], [row(3)]), %{
                 rows: [row(6)]
               })

      assert suggestion["cfb"]["0"] == "6"
    end

    assert {:ok, suggestion} = Allocation.suggest(state([], []), %{rows: [row(0)]})
    assert suggestion == %{"cfb" => %{"0" => "0"}, "ufb" => %{"0" => "0"}}
  end

  test "deux inventaires importés obligatoires, même s’ils sont vides" do
    for inventories <- [
          %{"cfb" => [], "ufb" => []},
          %{"cfb" => [%{rows: []}], "ufb" => []},
          %{"cfb" => [], "ufb" => [%{rows: []}]}
        ] do
      assert {:error, message} =
               Allocation.suggest(%{inventories: inventories}, %{rows: [row(1)]})

      assert message =~ "Importez les inventaires"
    end

    assert {:ok, suggestion} = Allocation.suggest(state([], []), %{rows: [row(1)]})
    assert suggestion["cfb"]["0"] == "1"
  end

  test "dernier inventaire utilisé et quantités de réception conservées" do
    snapshot = %{
      inventories: %{
        "cfb" => [%{rows: [row(10)]}, %{rows: [row(0)]}],
        "ufb" => [%{rows: [row(2)]}]
      }
    }

    assert {:ok, suggestion} = Allocation.suggest(snapshot, %{rows: [row(5), row(2, "U")]})
    assert suggestion == %{"cfb" => %{"0" => "0", "1" => "2"}, "ufb" => %{"0" => "5", "1" => "0"}}
  end
end
