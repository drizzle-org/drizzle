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
    %{gpio: gpio, currstate: false}
  end

  # map falsey values to a 0 or 1, as needed by Circuits.GPIO NIF
  defp intstate(state) when state in [false, nil], do: 0
  defp intstate(_state), do: 1

  defp do_status_change(zone_name, zonestruct, desiredstate) do
    DrizzleUiWeb.Endpoint.broadcast(@topic, "zone status change", %{
      zone: zone_name,
      newstate: desiredstate
    })

    # GPIO.write(0) actually turns ON the relay on the Waveshare RPi 8x relay board
    # this has to do with pull-up or down resitors, we might need to make this configurable
    :ok = Circuits.GPIO.write(zonestruct.gpio, intstate(!desiredstate))
    desiredstate
  end

  def handle_cast({:activate, zone}, state) do
    {:noreply,
      Enum.map(state, fn {zone_name, %{gpio: gpio, currstate: _cst} = zonestruct} -> {
        zone_name,
        # activate this zone, but turn off all other zones
        %{gpio: gpio, currstate: do_status_change(zone_name, zonestruct, zone_name == zone) }
      }
     end) |> Enum.into(%{})
    }
  end

  def handle_cast({:deactivate, zone}, state) do
    {:noreply,
      put_in(state, [zone, :currstate], do_status_change(zone, state[zone], false))
    }
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
