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

  def pulse(zone, duration, pid) do
    GenServer.cast(DrizzleIO, {:pulse, zone, duration, pid})
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
    # %{zone_name => %{:name => "...", :gpio => <handle>, :currstate => true/false}
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

  # performs the operation on the GPIO pin to flip a switch on/off
  defp do_status_change(zone_name, zonestruct, desiredstate) do
    DrizzleWeb.Endpoint.broadcast(@topic, "zone status change", %{
      zone: zone_name,
      newstate: desiredstate
    })
    # GPIO.write(0) actually turns ON the relay on the Waveshare RPi 8x relay board
    # this has to do with pull-up or down resitors, we might need to make this configurable
    :ok = Circuits.GPIO.write(zonestruct.gpio, intstate(!desiredstate))
    desiredstate
  end

  def handle_cast({:activate, zone}, state) do
    IO.puts("Activating #{zone}")
    {:noreply,
      Enum.map(state, fn {zone_name, %{gpio: gpio, currstate: _cst} = zonestruct} -> {
        zone_name,
        # activate this zone, but turn off all other zones
        %{gpio: gpio, currstate: do_status_change(zone_name, zonestruct, zone_name == zone) }
      }
     end) |> Enum.into(%{})
    }
  end

  def handle_cast({:deactivate, zone}, state), do: handle_info({:deactivate, zone, nil}, state)
  def handle_info({:deactivate, zone, pid}, state) do
    IO.puts("Deactivating #{zone}")
    do_status_change(zone, state[zone], false)
    # invoke scheduler callback to trigger next zone (if any)
    if is_pid(pid), do: Process.send(pid, {:zone_finished, zone}, [])
    # remove deactivation timer handle
    {_tmr, newstate} = pop_in(state, [zone, :deactivation_timer])
    #Process.cancel_timer(tmr)
    {:noreply,
      put_in(newstate, [zone, :currstate], false)
    }
  end

  def handle_cast({:pulse, zone, duration_millis, pid}, state) do
    # activate this zone now
    GenServer.cast(DrizzleIO, {:activate, zone})
    # and deactivate it after
    timer_ref = Process.send_after(
      self(), {:deactivate, zone, pid}, round(duration_millis))
    {:noreply,
      put_in(state, [zone, :deactivation_timer], timer_ref)
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
