defmodule FirstBricks.BSXTest do
  use ExUnit.Case, async: true
  alias FirstBricks.BSX

  def item(qty \\ "4", condition \\ "N", color \\ "5") do
    "<Item><ItemID>3001</ItemID><ItemTypeID>P</ItemTypeID><ColorID>#{color}</ColorID><Condition>#{condition}</Condition><Qty>#{qty}</Qty><ItemName>Brique &amp; test</ItemName><Price>0.25</Price><Remarks>Casier A</Remarks></Item>"
  end

  def wrap(items), do: "<BrickStoreXML><Inventory>#{items}</Inventory></BrickStoreXML>"

  test "parse, aggregation, états et couleurs distincts, métadonnées et export UTF-8" do
    assert {:ok, rows} =
             BSX.parse(wrap(item() <> item("2") <> item("0", "U") <> item("1", "N", "6")))

    assert length(rows) == 3
    row = Enum.find(rows, &(&1["Condition"] == "N" and &1["ColorID"] == "5"))
    assert row["Qty"] == 6
    assert row["ItemName"] == "Brique & test"
    assert {:ok, exported} = BSX.parse(BSX.export(rows))
    assert length(exported) == 2
    assert Enum.find(exported, &(&1["ColorID"] == "5"))["Remarks"] == "Casier A"
  end

  test "XML malformé, champs obligatoires et quantités invalides rejetés" do
    for bad <- [
          "oops",
          wrap(item("-1")),
          wrap(item("1.5")),
          wrap(item("3", "X")),
          wrap(String.replace(item(), "<ItemID>3001</ItemID>", "")),
          wrap(item("2147483648")),
          wrap(item("1", "N", "red"))
        ] do
      assert {:error, _} = BSX.parse(bad)
    end
  end

  test "DTD, entités, mauvaise racine et fichiers trop gros rejetés" do
    for bad <- [
          "<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///etc/passwd'>]>" <> wrap(item()),
          "<!ENTITY x 'y'>",
          "<Inventory/>",
          String.duplicate("x", BSX.max_bytes() + 1)
        ] do
      assert {:error, _} = BSX.parse(bad)
    end
  end

  @tag timeout: 60_000
  test "inventaire valide de plus de 17 Mo accepté" do
    rows =
      for i <- 1..90_000, into: "" do
        String.replace(item(), "<ItemID>3001</ItemID>", "<ItemID>large-#{i}</ItemID>")
      end

    xml = wrap(rows)
    assert byte_size(xml) > 17_000_000
    assert {:ok, parsed} = BSX.parse(xml)
    assert length(parsed) == 90_000
  end

  test "inventaire vide autorisé et export vide valide" do
    assert {:ok, []} = BSX.parse(BSX.export([]))
  end

  test "type fait partie de la clé" do
    assert {:ok, [a, b]} =
             BSX.parse(
               wrap(
                 item() <>
                   String.replace(
                     item(),
                     "<ItemTypeID>P</ItemTypeID>",
                     "<ItemTypeID>S</ItemTypeID>"
                   )
               )
             )

    refute BSX.key(a) == BSX.key(b)
  end
end
