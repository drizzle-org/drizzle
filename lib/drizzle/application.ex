defmodule Drizzle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @target Mix.target()

  use Application

  def start(_type, _args) do
    prepare_network()
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Drizzle.Supervisor]

    Supervisor.start_link(
      children(@target) ++
        [
          {Finch, name: DrizzleHTTP},
          Drizzle.Settings,
          {Drizzle.WeatherData, []},
          {Drizzle.IO, []},
          {Drizzle.Forecaster, %{}},
          {Drizzle.Scheduler, %{}},
          DrizzleWeb.Telemetry,
          {Phoenix.PubSub, [name: :drizzle_pubsub, adapter: Phoenix.PubSub.PG2]},
          DrizzleWeb.Endpoint
        ],
      opts
    )
  end

  def children(:host) do
    # children to run ONLY at the host for testing. Please try to keep this empty
    []
  end

  def children(_target) do
    # children to run ONLY at the target device. Please try to keep this empty
    []
  end

  defp prepare_network do
    IO.puts("===> prepare_network <===")

    if "wlan0" in VintageNet.all_interfaces() do
      # start the WiFi wizard if the wireless interface is not configured
      if "wlan0" not in VintageNet.configured_interfaces() do
        # start the WiFi wizard if the wireless interface is not configured
        IO.puts("===> Running VintageNetWizard <===")
        VintageNetWizard.run_wizard()
      end
    end
  end
end
