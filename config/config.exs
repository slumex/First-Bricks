import Config

config :first_bricks, FirstBricksWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: FirstBricksWeb.Errors], layout: false],
  pubsub_server: FirstBricks.PubSub,
  secret_key_base: String.duplicate("development-only-key-", 4),
  server: false

config :first_bricks, data_dir: "data", username: "admin", password: "change-me"
config :phoenix, :json_library, Jason
import_config "#{config_env()}.exs"
