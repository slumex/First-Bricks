defmodule FirstBricksWeb.Controller do
  use Phoenix.Controller, formats: [:html]
  alias FirstBricks.Store
  alias FirstBricksWeb.View
  def health(conn, _), do: text(conn, "ok")
  def index(conn, _), do: html(conn, View.index(Store.state()))

  def import(conn, %{"kind" => kind, "file" => %Plug.Upload{} = file})
      when kind in ["cfb", "ufb", "vendor"] do
    with {:ok, xml} <- File.read(file.path),
         {:ok, id} <- Store.import(kind, file.filename, xml) do
      redirect(conn, to: if(id, do: "/receptions/#{id}", else: "/"))
    else
      {:error, message} ->
        error(conn, if(is_binary(message), do: message, else: "Lecture du fichier impossible."))
    end
  end

  def import(conn, _), do: error(conn, "Choisissez un fichier BSX et une destination.")

  def show(conn, %{"id" => id}) do
    state = Store.state()

    case state.receptions[id] do
      nil -> not_found(conn)
      reception -> html(conn, View.reception(state, reception))
    end
  end

  def save(conn, %{"id" => id} = params) do
    case Store.allocate(id, params["revision"], params["cfb"], params["ufb"]) do
      :ok ->
        redirect(conn, to: "/receptions/#{id}?saved=1")

      {:error, message} ->
        case Store.state().receptions[id] do
          nil ->
            not_found(conn)

          reception ->
            conn
            |> put_status(422)
            |> html(View.reception(Store.state(), reception, message, params))
        end
    end
  end

  def export(conn, %{"id" => id, "site" => site}) when site in ["cfb", "ufb"] do
    case Store.state().receptions[id] do
      nil -> not_found(conn)
      reception -> download(conn, "repartition-#{site}-#{id}.bsx", Store.export(reception, site))
    end
  end

  def export(conn, _), do: not_found(conn)

  def original(conn, %{"site" => site, "id" => id}) when site in ["cfb", "ufb"] do
    case Enum.find(Store.state().inventories[site], &(&1.id == id)) do
      nil -> not_found(conn)
      inventory -> download(conn, "inventaire-#{site}-#{id}.bsx", inventory.xml)
    end
  end

  def original(conn, _), do: not_found(conn)

  defp download(conn, name, xml) do
    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{name}"))
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, xml)
  end

  defp error(conn, message),
    do: conn |> put_status(422) |> html(View.index(Store.state(), message))

  defp not_found(conn),
    do:
      conn
      |> put_status(404)
      |> html(View.layout("Introuvable", "<h1>Document introuvable</h1><a href='/'>Retour</a>"))
end
