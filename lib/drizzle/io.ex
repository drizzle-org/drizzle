defmodule Drizzle.IO do
  use GenServer

  @zone_pins Application.get_env(:drizzle, :zone_pins, %{})
  @topic "drizzle"

  # ======
  # Client
  # ======
  def start_link(_args) do
    {:ok, _} = GenServer.start_link(__MODULE__, [], name: DrizzleIO)
  end

  def activate(zone) do
    GenServer.cast(DrizzleIO, {:activate, zone})
  end

  def deactivate(zone) do
    GenServer.cast(DrizzleIO, {:deactivate, zone})
  end

  def read_soil_moisture(pin \\ 2) do
    GenServer.call(DrizzleIO, {:read_soil_moisture, pin})
  end

  def zonestate() do
    GenServer.call(DrizzleIO, :zonestate)
  end

  # ======
  # Server
  # ======
  def init(_state) do
    IO.puts("Starting Drizzle.IO")
    IO.inspect(Circuits.GPIO.info(), label: "Circuits.GPIO")
    # %{zone_name => %{:gpio =>.. , :currstate => true/false}
    state =
      @zone_pins
      |> Enum.map(fn {name, pin} -> {name, pin |> init_output()} end)

    {:ok, state}
  end

  defp init_output(pin) do
    {:ok, gpio} = Circuits.GPIO.open(pin, :output)
    :ok = Circuits.GPIO.write(gpio, 1)
    %{gpio: gpio, currstate: 0}
  end

  defp do_status_change(zone_name, zonestruct, newstate) do
    intstate = (newstate && 1 || 0)
    DrizzleUiWeb.Endpoint.broadcast @topic, "zone status change", %{zone: zone_name, newstate: intstate}
    :ok = Circuits.GPIO.write(zonestruct.gpio, (!newstate && 1 || 0))
    intstate
  end

  def handle_cast({:activate, zone}, state) do
    {:noreply,
    # activate this zone, but turn off all other zones
     state
     |> Enum.map(fn {zone_name, %{gpio: gpio, currstate: _cst} = zonestruct} ->
       {zone_name, %{gpio: gpio, currstate: do_status_change(zone_name, zonestruct, zone_name == zone) }}
     end)}
  end

  def handle_cast({:deactivate, zone}, state) do
    {:noreply,
     Map.put(state, zone, do_status_change(zone, state[zone], false))}
  end

  def handle_call({:read_soil_moisture, pin}, _from, state) do
    {:ok, gpio} = Circuits.GPIO.open(pin, :input)
    moisture = Circuits.GPIO.read(gpio)
    Circuits.GPIO.close(gpio)
    {:reply, moisture, state}
  end

  def handle_call(:zonestate, _from, state) do
    {:reply, state, state}
  end

end
