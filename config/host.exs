import Config

# Stub Circuits.GPIO to be used on host
System.put_env("CIRCUITS_MIX_ENV", "test")

config :vintage_net_wizard,
  backend: VintageNetWizard.Backend.Mock,
  port: 4001,
  captive_portal: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :drizzle, DrizzleWeb.Endpoint,
  http: [port: 4002],
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :drizzle, DrizzleWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/drizzle_web/(live|views)/.*(ex)$",
      ~r"lib/drizzle_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :nerves_runtime, target: "host"

config :vintage_net,
  resolvconf: "/dev/null",
  persistence: VintageNet.Persistence.Null,
  bin_ip: "false"

config :drizzle,
  # gpio_module: Drizzle.GPIO
  database_dir: Path.expand(Path.join(__DIR__, "../tmp"))

