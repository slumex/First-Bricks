defmodule FirstBricksWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :first_bricks
  plug(Plug.Static, at: "/", from: :first_bricks, only: ~w(css js))
  plug(Plug.RequestId)
  plug(FirstBricksWeb.UploadParser)
  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_first_bricks",
    signing_salt: "first-bricks-v1",
    same_site: "Lax",
    secure: Mix.env() == :prod
  )

  plug(FirstBricksWeb.Router)
end

defmodule FirstBricksWeb.Errors do
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
