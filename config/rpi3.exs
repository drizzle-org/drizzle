use Mix.Config

# Add the RingLogger backend. This removes the
# default :console backend.
config :logger, backends: [RingLogger]

# Set the number of messages to hold in the circular buffer
config :logger, RingLogger, max_size: 8192

config :ring_logger,
  #application_levels: %{drizzle_ui: :debug},
  color: [debug: :yellow],
  level: :debug

# Authorize the device to receive firmware using your public key.
# See https://hexdocs.pm/nerves_firmware_ssh/readme.html for more information
# on configuring nerves_firmware_ssh.

keys =
  [
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
  ]
  |> Enum.filter(&File.exists?/1)

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_firmware_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

# GPIO pin 2 is directly next to 3.3V so adding a jumper over them for
# 5 seconds should suffice to get the vintage_wifi_wizard up and running
config :vintage_net_wizard,
  gpio_pin: 2,
  port: 81

  # Configures the endpoint
config :drizzle_ui, DrizzleUiWeb.Endpoint,
  url: [host: "drizzle.local", port: 80],
  http: [ip: {0, 0, 0, 0}, port: 80]

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
