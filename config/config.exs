import Config

config :drizzle, target: Mix.target()

# Customize non-Elixir parts of the firmware.  See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.
config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1591293559"

config :drizzle,
  # soil_moisture_sensor: %{pin: 26, min: 0, max: 539},
  # For Waveshare RPi relay board (B variant, 8 relays)
  # https://www.waveshare.com/rpi-relay-board-b.htm
  zone_pins: %{
    zone1: 5,
    zone2: 6,
    zone3: 13,
    zone4: 16,
    zone5: 19,
    zone6: 20,
    zone7: 21,
    zone8: 26
  },
  # visit https://developer.climacell.co/ to get an API key
  climacell_api_key: System.get_env("CLIMACELL_API_KEY")

# import Phoenix config
# Configures the endpoint
config :drizzle, DrizzleWeb.Endpoint,
  # Use compile-time Mix config instead of runtime environment variables
  load_from_system_env: false,
  # Start the server since we're running in a release instead of through `mix`
  server: true,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false,
  secret_key_base: "R6vmyPo7uGwXniRcOCsspyeoBjoh1RdJl9HGu+taCfhhSfAdd3BwVrT5kIqfmk2w",
  render_errors: [view: DrizzleWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: :drizzle_pubsub,
  live_view: [signing_salt: "c2+eUgj3"],
  check_origin: false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
