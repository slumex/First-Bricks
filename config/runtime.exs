import Config

if config_env() in [:prod, :local] do
  local? = config_env() == :local

  secret =
    if local?,
      do: System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(64)),
      else: System.fetch_env!("SECRET_KEY_BASE")

  password =
    if local?,
      do: System.get_env("APP_PASSWORD", "local-first-bricks-2026"),
      else: System.fetch_env!("APP_PASSWORD")

  if byte_size(secret) < 64, do: raise("SECRET_KEY_BASE doit contenir au moins 64 caractères")
  if byte_size(password) < 16, do: raise("APP_PASSWORD doit contenir au moins 16 caractères")

  config :first_bricks,
    data_dir: System.get_env("DATA_DIR", "/data"),
    username: System.get_env("APP_USERNAME", "admin"),
    password: password

  config :first_bricks, FirstBricksWeb.Endpoint,
    server: true,
    secret_key_base: secret,
    url: [
      scheme: if(local?, do: "http", else: "https"),
      host: if(local?, do: "localhost", else: System.fetch_env!("PHX_HOST")),
      port: if(local?, do: 4000, else: 443)
    ],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))]
end
