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
    prepare_network()
    [
      {Finch, name: DrizzleHTTP},
      {Drizzle.WeatherData, []},
      {Drizzle.IO, []},
      {Drizzle.Scheduler, %{}},
      {Drizzle.Forecaster, %{}},
      {Drizzle.TodaysEvents, []}
    ]
  end

  def wait_for_internet(iface) do
    IO.puts "waiting for #{iface} to become ready..."
    VintageNet.subscribe(["interface", iface])
    receive do
      {VintageNet, ["interface", ifname, "connection"], _oldstate, :internet, _} ->
        IO.puts "===> #{ifname} configured <==="
        start_phoenix()
      _ -> wait_for_internet(iface)
    end
  end

  defp prepare_network do
    IO.puts "===> prepare_network <==="
    if "wlan0" in VintageNet.all_interfaces() do
        # start the WiFi wizard if the wireless interface is not configured
        if "wlan0" in VintageNet.configured_interfaces() do
          # start the WiFi wizard if the wireless interface is not configured
          IO.puts "===> Running VintageNetWizard <==="
          VintageNetWizard.run_wizard(on_exit: {__MODULE__, :wait_for_internet, ["wlan0"]})
        else
          wait_for_internet("wlan0")
        end
    else
      wait_for_internet("eth0")
    end
  end

  defp start_phoenix do
    IO.puts "===> Starting Phoenix <==="
    Application.ensure_all_started(:drizzle_ui)
  end

end
