import Config

if config_env() == :prod do
  secret = System.fetch_env!("SECRET_KEY_BASE")
  password = System.fetch_env!("APP_PASSWORD")
  if byte_size(secret) < 64, do: raise("SECRET_KEY_BASE doit contenir au moins 64 caractères")
  if byte_size(password) < 16, do: raise("APP_PASSWORD doit contenir au moins 16 caractères")

  config :first_bricks,
    data_dir: System.get_env("DATA_DIR", "/data"),
    username: System.get_env("APP_USERNAME", "admin"),
    password: password

  config :first_bricks, FirstBricksWeb.Endpoint,
    server: true,
    secret_key_base: secret,
    url: [scheme: "https", host: System.fetch_env!("PHX_HOST"), port: 443],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))]
end
