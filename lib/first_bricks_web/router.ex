defmodule FirstBricksWeb.Auth do
  def init(opts), do: opts

  def call(conn, _) do
    Plug.BasicAuth.basic_auth(conn,
      username: Application.fetch_env!(:first_bricks, :username),
      password: Application.fetch_env!(:first_bricks, :password),
      realm: "Altreus Inventory Optimizer (AIO)"
    )
  end
end

defmodule FirstBricksWeb.Router do
  use Phoenix.Router

  pipeline :browser do
    plug(FirstBricksWeb.Auth)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)

    plug(:put_secure_browser_headers, %{
      "cache-control" => "no-store",
      "content-security-policy" =>
        "default-src 'self'; style-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'"
    })
  end

  get("/health", FirstBricksWeb.Controller, :health)

  scope "/", FirstBricksWeb do
    pipe_through(:browser)
    get("/", Controller, :index)
    post("/imports", Controller, :import)
    get("/inventories/:site/:id", Controller, :original)
    get("/receptions/:id", Controller, :show)
    post("/receptions/:id", Controller, :save)
    get("/receptions/:id/exports/:site", Controller, :export)
  end
end
