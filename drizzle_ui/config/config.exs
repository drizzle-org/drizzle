# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :drizzle_ui, DrizzleUiWeb.Endpoint,
  url: [host: "drizzle.local", port: 80],
  # Use compile-time Mix config instead of runtime environment variables
  load_from_system_env: false,
  # Start the server since we're running in a release instead of through `mix`
  server: true,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false,
  secret_key_base: "R6vmyPo7uGwXniRcOCsspyeoBjoh1RdJl9HGu+taCfhhSfAdd3BwVrT5kIqfmk2w",
  render_errors: [view: DrizzleUiWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: DrizzleUi.PubSub,
  live_view: [signing_salt: "c2+eUgj3"]


# Configures Elixir's Logger
config :logger, :RingLogger,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
#import_config "#{Mix.Project.config()[:target]}.exs"
