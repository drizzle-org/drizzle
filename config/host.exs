import Config

# Stub Circuits.GPIO to be used on host
System.put_env("CIRCUITS_MIX_ENV", "test")

config :vintage_net_wizard,
  backend: VintageNetWizard.Backend.Mock,
  port: 4001,
  captive_portal: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :drizzle_ui, DrizzleUiWeb.Endpoint,
  http: [port: 4002],
  server: true

config :nerves_runtime, target: "host"

config :vintage_net,
  resolvconf: "/dev/null",
  persistence: VintageNet.Persistence.Null,
  bin_ip: "false"

  config :drizzle,
    # gpio_module: Drizzle.GPIO
    schedule_dir: Path.expand(Path.join(__DIR__, "../tmp"))
