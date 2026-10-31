defmodule FirstBricksWeb.View do
  alias FirstBricks.{BSX, Store}
  defp e(x), do: BSX.escape(x)

  defp token,
    do:
      "<input type='hidden' name='_csrf_token' value='#{e(Plug.CSRFProtection.get_csrf_token())}'>"

  def layout(title, body) do
    """
    <!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>#{e(title)} · First Bricks</title><link rel="stylesheet" href="/css/app.css"></head>
    <body><header><a class="brand" href="/">▦ FIRST BRICKS</a><span>Gestion des inventaires · Canada / USA</span></header><main>#{body}</main><footer>CFB : Canada First Bricks · UFB : USA First Bricks<br>Échanges BSX · Compatibilité Altreus à valider sur fichiers réels</footer></body></html>
    """
  end

  defp alert(nil), do: ""
  defp alert(message), do: "<div class='alert' role='alert'>#{e(message)}</div>"

  def index(state, error \\ nil) do
    cards =
      Enum.map_join(
        [{"cfb", "Canada", "Altreus CFB"}, {"ufb", "États-Unis", "Altreus UFB"}],
        fn {site, name, platform} ->
          current = List.first(state.inventories[site])

          summary =
            if current,
              do:
                "<strong>#{length(current.rows)} lots</strong><p>#{e(current.name)}<br>#{e(current.imported_at)}</p>",
              else:
                "<strong>Aucun inventaire importé</strong><p>Importez votre premier fichier BSX.</p>"

          history =
            Enum.map_join(state.inventories[site], fn item ->
              "<li><a href='/inventories/#{site}/#{item.id}'>#{e(item.name)}</a> <small>#{e(item.imported_at)}</small></li>"
            end)

          "<section class='card'><span class='tag'>#{String.upcase(site)}</span><h2>#{name}</h2><p>#{platform}</p>#{summary}#{upload(site, "Importer l’inventaire")}<details><summary>Historique des originaux (#{length(state.inventories[site])})</summary><ul>#{history}</ul></details></section>"
        end
      )

    receptions =
      state.receptions
      |> Map.values()
      |> Enum.sort_by(& &1.imported_at, :desc)
      |> Enum.map_join(fn r ->
        total = Enum.sum(Enum.map(r.rows, & &1["Qty"]))
        assigned = Enum.sum(Enum.map(r.allocations, fn {_, a} -> a["cfb"] + a["ufb"] end))

        "<a class='reception' href='/receptions/#{r.id}'><div><strong>#{e(r.name)}</strong><small>#{e(r.imported_at)} · #{length(r.rows)} lots</small></div><span>#{assigned} / #{total} attribuées →</span></a>"
      end)

    layout("Tableau de bord", """
    <div class="eyebrow">VOTRE ESPACE DE RÉPARTITION</div><h1>Chaque pièce à sa place.</h1><p class="lead">Comparez vos stocks, répartissez une réception et préparez vos imports Altreus.</p>#{alert(error)}
    <div class="grid">#{cards}</div>
    <section class="card"><div class="eyebrow">NOUVELLE RÉCEPTION</div><h2>Recevoir un inventaire vendor</h2><p>Les quantités reçues peuvent être attribuées au Canada, aux États-Unis ou partagées.</p>#{upload("vendor", "Importer la réception")}</section>
    <section><h2>Réceptions enregistrées</h2>#{if receptions == "", do: "<p>Aucune réception pour le moment.</p>", else: receptions}</section>
    """)
  end

  defp upload(kind, button) do
    "<form action='/imports' method='post' enctype='multipart/form-data'>#{token()}<input type='hidden' name='kind' value='#{kind}'><label>Fichier BSX (UTF-8, 5 Mo maximum)<input type='file' name='file' accept='.bsx,.xml' required></label><button>#{button}</button></form>"
  end

  def reception(state, r, error \\ nil, submitted \\ %{}) do
    total = Enum.sum(Enum.map(r.rows, & &1["Qty"]))
    assigned = Enum.sum(Enum.map(r.allocations, fn {_, a} -> a["cfb"] + a["ufb"] end))

    rows =
      r.rows
      |> Enum.with_index()
      |> Enum.map_join(fn {row, i} ->
        k = Integer.to_string(i)
        a = r.allocations[k]

        cells =
          Enum.map_join(["cfb", "ufb"], fn site ->
            value = get_in(submitted, [site, k]) || a[site]

            "<td><label class='sr-only' for='#{site}-#{i}'>Attribution #{String.upcase(site)} ligne #{i + 1}</label><input id='#{site}-#{i}' class='qty' type='number' name='#{site}[#{i}]' min='0' max='#{row["Qty"]}' step='1' required value='#{e(value)}'></td>"
          end)

        "<tr><td><strong>#{e(row["ItemID"])}</strong><small>#{e(row["ItemName"])} · Type #{e(row["ItemTypeID"])}</small></td><td>#{e(row["ColorName"])}<small>Couleur #{e(row["ColorID"])}</small></td><td>#{if row["Condition"] == "N", do: "Neuf", else: "Usagé"}</td><td>#{stock(Store.stock(state, "cfb", row))}</td><td>#{stock(Store.stock(state, "ufb", row))}</td><td><strong>#{row["Qty"]}</strong></td>#{cells}<td>#{row["Qty"] - a["cfb"] - a["ufb"]}</td></tr>"
      end)

    layout(r.name, """
    <a href="/">← Tableau de bord</a><div class="eyebrow">RÉCEPTION VENDOR</div><h1>#{e(r.name)}</h1>
    <p class="lead">#{length(r.rows)} lots · #{total} pièces reçues · #{assigned} attribuées · #{total - assigned} à répartir</p>
    #{alert(error)}<p>Stocks : dernier inventaire importé de chaque plateforme. « Absent » et « Présent · 0 » sont distincts. Les attributions ne modifient pas les inventaires de référence.</p>
    <form action="/receptions/#{r.id}" method="post">#{token()}<input type="hidden" name="revision" value="#{r.revision}">
    <div class="table-wrap"><table><thead><tr><th>Pièce</th><th>Couleur</th><th>État</th><th>Stock CFB</th><th>Stock UFB</th><th>Reçu</th><th>Attribuer CFB</th><th>Attribuer UFB</th><th>Reste enregistré</th></tr></thead><tbody>#{rows}</tbody></table></div>
    <div class="actions"><button>Enregistrer la répartition</button><span>CFB + UFB ne doit pas dépasser la quantité reçue de chaque lot.</span></div></form>
    <section class="card"><h2>Exporter la répartition enregistrée</h2><p>Chaque fichier contient uniquement les quantités attribuées à sa destination. Enregistrez vos modifications avant de télécharger. Les quantités non attribuées sont exclues.</p><div class="actions"><a class="button secondary" href="/receptions/#{r.id}/exports/cfb">Télécharger CFB.bsx</a><a class="button secondary" href="/receptions/#{r.id}/exports/ufb">Télécharger UFB.bsx</a></div><p>Les exports sont des ajouts de stock, pas des inventaires complets. Vérifiez le mode d’import dans Altreus.</p></section>
    """)
  end

  defp stock(:not_imported), do: "<span class='muted'>Non importé</span>"
  defp stock(:absent), do: "<span class='muted'>Absent</span>"
  defp stock({:present, n}), do: "<span class='present'>Présent · #{n}</span>"
end
