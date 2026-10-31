defmodule FirstBricks.StoreTest do
  use ExUnit.Case, async: false
  alias FirstBricks.{Store, BSX}
  defp xml, do: File.read!("examples/reception-vendor.bsx")

  test "stocks non importés, absents et présents à zéro distincts" do
    {:ok, [row | _]} = BSX.parse(xml())
    state = %{inventories: %{"cfb" => []}}
    assert Store.stock(state, "cfb", row) == :not_imported
    state = %{inventories: %{"cfb" => [%{rows: []}]}}
    assert Store.stock(state, "cfb", row) == :absent
    state = %{inventories: %{"cfb" => [%{rows: [Map.put(row, "Qty", 0)]}]}}
    assert Store.stock(state, "cfb", row) == {:present, 0}
    assert Store.stock(state, "cfb", Map.put(row, "Condition", "U")) == :absent
  end

  test "répartition partagée, dépassement atomique, conflit et exports" do
    {:ok, id} = Store.import("vendor", "reception.bsx", xml())
    cfb = %{"0" => "2", "1" => "0", "2" => "1"}
    ufb = %{"0" => "3", "1" => "4", "2" => "0"}
    assert :ok = Store.allocate(id, "0", cfb, ufb)
    reception = Store.state().receptions[id]
    assert {:error, _} = Store.allocate(id, "1", Map.put(cfb, "0", "99"), ufb)
    assert Store.state().receptions[id] == reception
    assert {:error, _} = Store.allocate(id, "0", cfb, ufb)

    for bad <- [
          Map.delete(cfb, "0"),
          Map.put(cfb, "0", "-1"),
          Map.put(cfb, "0", "1.5"),
          Map.put(cfb, "3", "0"),
          nil
        ] do
      assert {:error, _} = Store.allocate(id, "1", bad, ufb)
    end

    assert {:ok, a} = BSX.parse(Store.export(reception, "cfb"))
    assert {:ok, b} = BSX.parse(Store.export(reception, "ufb"))
    assert Enum.sum(Enum.map(a, & &1["Qty"])) == 3
    assert Enum.sum(Enum.map(b, & &1["Qty"])) == 7
    assert reception.xml == xml()
  end

  test "historiques des inventaires conservés, inventaire courant remplacé, persistance après redémarrage" do
    {:ok, _} = Store.import("cfb", "initial.bsx", xml())
    previous = Store.state().inventories["cfb"]
    {:ok, _} = Store.import("cfb", "vide.bsx", BSX.export([]))
    assert tl(Store.state().inventories["cfb"]) == previous
    {:ok, id} = Store.import("vendor", "persist.bsx", xml())

    assert :ok =
             Store.allocate(id, "0", %{"0" => "1", "1" => "0", "2" => "0"}, %{
               "0" => "0",
               "1" => "0",
               "2" => "0"
             })

    saved = Store.state()
    :ok = Supervisor.terminate_child(FirstBricks.Supervisor, Store)
    {:ok, _} = Supervisor.restart_child(FirstBricks.Supervisor, Store)
    assert Store.state() == saved
  end

  test "réception vide et import malformé sans effet" do
    before = Store.state()
    assert {:error, _} = Store.import("vendor", "empty.bsx", BSX.export([]))
    assert {:error, _} = Store.import("cfb", "bad.bsx", "<bad>")
    assert Store.state() == before
  end
end
