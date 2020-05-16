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
    if "wlan0" in VintageNet.configured_interfaces() do
      handle_wizard_exit()
    else
      # start the WiFi wizard if the wireless interface is not configured
      IO.puts "===> Running VintageNetWizard <==="
      VintageNetWizard.run_wizard(on_exit: {__MODULE__, :handle_wizard_exit, []})
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

  def handle_wizard_exit() do
    VintageNet.subscribe(["interface", "wlan0"])
    receive do
      {VintageNet, ["interface", ifname, "connection"], _oldstate, :internet, _} ->
        IO.puts "===> #{ifname} configured, status: #{inspect status} <==="
        Application.ensure_all_started(:drizzle_ui)
      _ -> loop
    end
  end

  defp wifi_check_wizard
    "wlan0" in VintageNet.all_interfaces()
  end
end
