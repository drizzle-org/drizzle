defmodule Drizzle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @target Mix.target()

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Drizzle.Supervisor]
    Supervisor.start_link(children(@target), opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      {Finch, name: DrizzleHTTP}
    ]
  end

  def children(target) do
    # start the WiFi wizard if the wireless interface is not configured
    unless "wlan0" in VintageNet.configured_interfaces() do
      VintageNetWizard.run_wizard()
    end

    [
      {Finch, name: DrizzleHTTP},
      {Drizzle.WeatherData, []},
      {Drizzle.IO, []},
      {Drizzle.Scheduler, %{}},
      {Drizzle.Forecaster, %{}},
      {Drizzle.TodaysEvents, []}
    ]
  end
end
