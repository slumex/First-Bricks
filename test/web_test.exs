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
