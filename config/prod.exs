import Config
config :logger, level: :info

config :first_bricks, FirstBricksWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto], exclude: [paths: ["/health"]]]
