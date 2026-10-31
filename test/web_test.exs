defmodule FirstBricks.WebTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Phoenix.ConnTest
  @endpoint FirstBricksWeb.Endpoint
  defp auth(conn),
    do:
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> put_req_header("authorization", "Basic " <> Base.encode64("admin:change-me"))

  defp browser do
    conn = build_conn() |> auth() |> get("/")
    [_, token] = Regex.run(~r/name='_csrf_token' value='([^']+)'/, html_response(conn, 200))
    {conn |> recycle() |> auth(), token}
  end

  test "santé publique et écran protégé en français" do
    assert response(get(build_conn(), "/health"), 200) == "ok"
    assert response(get(build_conn(), "/"), 401) =~ "Unauthorized"
    conn = build_conn() |> auth() |> get("/")
    assert html_response(conn, 200) =~ "Chaque pièce à sa place"
    assert get_resp_header(conn, "content-security-policy") != []
  end

  test "import multipart, sauvegarde et téléchargement de deux BSX" do
    {conn, token} = browser()

    upload = %Plug.Upload{
      path: "examples/reception-vendor.bsx",
      filename: "vendor.bsx",
      content_type: "application/xml"
    }

    conn = post(conn, "/imports", %{"_csrf_token" => token, "kind" => "vendor", "file" => upload})
    path = redirected_to(conn)
    conn = conn |> recycle() |> auth() |> get(path)
    body = html_response(conn, 200)
    assert body =~ "vendor.bsx"
    assert body =~ "Attribuer CFB"
    [_, token] = Regex.run(~r/name='_csrf_token' value='([^']+)'/, body)

    conn =
      conn
      |> recycle()
      |> auth()
      |> post(path, %{
        "_csrf_token" => token,
        "revision" => "0",
        "cfb" => %{"0" => "5", "1" => "0", "2" => "0"},
        "ufb" => %{"0" => "5", "1" => "4", "2" => "3"}
      })

    assert redirected_to(conn) =~ path

    for site <- ["cfb", "ufb"] do
      exported = build_conn() |> auth() |> get(path <> "/exports/" <> site)
      assert {:ok, [_ | _]} = FirstBricks.BSX.parse(response(exported, 200))
      assert get_resp_header(exported, "content-disposition") |> hd() =~ ".bsx"
      assert response(get(build_conn(), path <> "/exports/" <> site), 401) =~ "Unauthorized"
    end
  end

  test "bouton attribuer : proposition modifiable sans sauvegarde puis enregistrement et conflit" do
    for site <- ["cfb", "ufb"] do
      assert {:ok, nil} =
               FirstBricks.Store.import(
                 site,
                 "stock.bsx",
                 File.read!("examples/inventaire-#{site}.bsx")
               )
    end

    {:ok, id} =
      FirstBricks.Store.import(
        "vendor",
        "vendor.bsx",
        File.read!("examples/reception-vendor.bsx")
      )

    path = "/receptions/#{id}"

    assert :ok =
             FirstBricks.Store.allocate(id, "0", %{"0" => "1", "1" => "0", "2" => "0"}, %{
               "0" => "0",
               "1" => "0",
               "2" => "0"
             })

    saved = FirstBricks.Store.state().receptions[id]
    {conn, token} = browser()
    conn = post(conn, path, %{"_csrf_token" => token, "revision" => "1", "action" => "auto"})
    body = html_response(conn, 200)
    assert body =~ "Attribuer les stocks"
    assert body =~ "Rien n’a encore été sauvegardé"
    fields = Regex.scan(~r/name='(cfb|ufb)\[(\d+)\]'[^>]*value='(\d+)'/, body)

    proposal =
      Enum.reduce(fields, %{"cfb" => %{}, "ufb" => %{}}, fn [_, site, line, qty], acc ->
        put_in(acc, [site, line], qty)
      end)

    assert proposal == %{
             "cfb" => %{"0" => "10", "1" => "4", "2" => "0"},
             "ufb" => %{"0" => "0", "1" => "0", "2" => "3"}
           }

    assert FirstBricks.Store.state().receptions[id] == saved
    # L’utilisateur peut ajuster la proposition avant de sauvegarder.
    proposal = proposal |> put_in(["cfb", "0"], "7") |> put_in(["ufb", "0"], "3")
    [_, token] = Regex.run(~r/name='_csrf_token' value='([^']+)'/, body)

    conn =
      conn
      |> recycle()
      |> auth()
      |> post(path, Map.merge(proposal, %{"_csrf_token" => token, "revision" => "1"}))

    assert redirected_to(conn) =~ path
    current = FirstBricks.Store.state().receptions[id]
    assert current.allocations["0"] == %{"cfb" => 7, "ufb" => 3}

    conn =
      conn
      |> recycle()
      |> auth()
      |> post(path, %{"_csrf_token" => token, "revision" => "1", "action" => "auto"})

    assert html_response(conn, 422) =~ "Rechargez la page"
    assert FirstBricks.Store.state().receptions[id] == current
  end

  test "requête trop volumineuse renvoie une explication française" do
    body = String.duplicate("x", FirstBricks.BSX.max_bytes() + 1_000_001)

    conn =
      Plug.Test.conn(:post, "/imports", body)
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> FirstBricksWeb.UploadParser.call([])

    assert conn.status == 413
    assert conn.halted
    assert conn.resp_body =~ "50 Mo"
    assert conn.resp_body =~ "Retour au tableau de bord"
  end

  test "requête sans jeton CSRF bloquée" do
    assert_error_sent(403, fn ->
      build_conn() |> auth() |> post("/imports", %{"kind" => "vendor"})
    end)
  end

  test "erreur d’import rendue sans injection HTML" do
    {conn, token} = browser()
    conn = post(conn, "/imports", %{"_csrf_token" => token, "kind" => "vendor"})
    assert html_response(conn, 422) =~ "Choisissez un fichier"
    assert FirstBricks.BSX.escape("<script>'&") == "&lt;script&gt;&#39;&amp;"
  end
end
