use Mix.Config

config :vintage_net_wizard,
  backend: VintageNetWizard.Backend.Mock

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :drizzle_ui, DrizzleUiWeb.Endpoint,
  http: [port: 4002],
  server: true

config :drizzle,
  # gpio_module: Drizzle.GPIO
  schedule_dir: Path.expand(Path.join(__DIR__, "../tmp"))
