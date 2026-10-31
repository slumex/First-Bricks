defmodule FirstBricksWeb.UploadParser do
  @moduledoc "Limite multipart cohérente avec le parseur BSX, marge pour les champs et en-têtes."
  import Plug.Conn
  alias FirstBricks.BSX
  def init(opts), do: opts

  def call(conn, _) do
    options =
      Plug.Parsers.init(
        parsers: [:urlencoded, :multipart],
        pass: [],
        length: BSX.max_bytes() + 1_000_000,
        read_timeout: 120_000
      )

    Plug.Parsers.call(conn, options)
  rescue
    Plug.Parsers.RequestTooLargeError ->
      body =
        "<!doctype html><html lang='fr'><meta charset='utf-8'><title>Fichier trop volumineux</title><h1>Fichier trop volumineux</h1><p>La limite par fichier BSX est de #{BSX.max_label()}. Choisissez un fichier plus petit.</p><a href='/'>Retour au tableau de bord</a></html>"

      conn |> put_resp_content_type("text/html") |> send_resp(413, body) |> halt()
  end
end
