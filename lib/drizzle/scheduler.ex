defmodule Drizzle.Scheduler do
@moduledoc """
  Implements an advanced irrigation schedule controller for Drizzle.
  Terminology:

  - `schedule_config`: the human-readable, WebUI driven configuration that drives the schedule.
    It contains only tuples with atoms and integers, for basically 4 clauses:
    * `duration` - base time for the zone, eg. `{10, :minutes}`
    * `variance` - should the base time vary with weather conditions or be a fixed value (:fixed/:variable)
    * `frequency` - how often should the zone be irrigated, eg `{:every, 2, :days}` or `{:on, [:mon, :fri]}`
    * `trigger` - what trigggers the zone, either an astronomical event like sunset, or simply another zone.
      The triggers are quite powerful that are themselves broken down in 1)offset 2)before/after and 3)exactly/on.
      You can use `sunrise/noon/sunset` and `midnight`. These are *astronomical* times and are calculated
      based on your longitute/latitude. Expect them to vary from your wall clock!

      Some examples:

      * `{{3, :hours}, :before, :sunrise}}` - start the zone three hours before sunrise
      * `{:chain,      :after,  :zone2}}` - start the zone after zone2 has finished
      * `{:exactly,    :at,     :noon}}`  - start the zone at solar noon

  - `schedule`: a dynamic volatile struct that applies the config onto concrete datetimes for the zone trigger events.
    The schedule only contains timers and next_occurrence timestamps for zones that are triggered by *time triggers*
    It does **not** define next_occurrence dates and timers for chained zones.

  - For display purposes you might want to use `explain_schedule/0`, which will derive each zone's actual scheduled occurrence
    by working out all zones, (including chained zones) duration + the initiating zone start time.

  - All datetimes are stored in `UTC` internally and need to be converted to the user's locale for diplay purposes

"""

  use GenServer
  alias Drizzle.Settings

  @topic "drizzle"

  def default_config(), do: %{
    #        duration        variance    frequency          trigger_clause
    #                                    base  val  unit    offset      after/before  condition
    zone1: {{5,  :minutes}, :fixed,    {:every, 2, :days}, {{3, :hours},   :before, :sunrise}},
    zone2: {{10, :seconds}, :variable, {:every, 1, :days}, {{3, :seconds}, :after,  :now}},
    zone3: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone2}},
    zone4: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone3}},
    zone5: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone4}},
    zone6: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone5}},
    zone7: {{20, :minutes}, :variable, {:every, 3, :days}, {:exactly,      :at,     :noon}},
    zone8: {{10, :minutes}, :fixed,    {:on, [:mon, :fri]}, {{30, :minutes}, :after, :sunset}}
  }
  @type duration_units :: :seconds | :minutes

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      astro: %{
        latitude:  Settings.latitude() || (System.get_env("LATITUDE", "37.983810") |> String.to_float),
        longitude: Settings.longitude()|| (System.get_env("LONGITUDE", "23.727539") |> String.to_float)
      },
      schedule_config: Settings.scheduler_config() || default_config()
    },
    name: DrizzleScheduler)
  end

  def init(initstate), do: {:ok, Map.merge(initstate, %{schedule: todays_tasks(initstate)})}
  def get_schedule_config() do
    GenServer.call(DrizzleScheduler, :get_schedule_config)
  end
  @doc "returns the current schedule, including next occurences for chained zones"
  def explain_schedule() do
    GenServer.call(DrizzleScheduler, :get_schedule) |> schedule_explained()
  end

  # get a schedule explanation, meaning it has populated all zones expected next occurrences
  # including chained zones (which dont have their own trigger event), but rely on another zone's finished event
  defp schedule_explained(sch) do
    sch |> Enum.map(fn {zone, zinfo} -> {zone,
      duration_seconds: round(zinfo.dur/1000),
      next_occurrence:  zone_next_occurrence(sch, zone)
    } end)
    |> Enum.into(%{})
  end

  @doc "recursively work out a zone's next occurrence by adding up all chained zones durations"
  def zone_next_occurrence(sch, zone) when is_map_key(zone, :hour), do: Access.get(sch[zone], :next) || Timex.now()
  def zone_next_occurrence(sch, zone) do
    Access.get(sch[zone], :next) || Timex.add(
      zone_next_occurrence(sch, sch[zone].trig),
      Timex.Duration.from_milliseconds(sch[zone].dur)
    )
  end

  @doc "pubsub event handler for UI scheduler config changes"
  def handle_cast(:scheduler_config_changed, state), do: {:noreply, generate_schedule(state)}
  @doc "sync call to retrieve the schedule configuration"
  def handle_call(:get_schedule_config, _from, state), do: {:reply, state.schedule_config, state}
  @doc "sync call to retrieve the current schedule"
  def handle_call(:get_schedule, _from, state), do: {:reply, state.schedule, state}
  @doc "Drizzle.IO callback to inform the schedule that a zone has finished irrigating"
  def handle_info({:zone_finished, zone}, state) do
    # is this zone chained to another?
    {nextzone, nextinfo} =
      state.schedule |> Enum.find({nil, nil}, fn({_nextzone, all}) -> all.trig == zone end)
    #
    {_, state} = pop_in(state, [:schedule, zone, :next])
    {_, state} = pop_in(state, [:schedule, zone, :timer])
    {:noreply,
      if !is_nil(nextzone) do
        Drizzle.IO.pulse(nextzone, nextinfo.dur, self())
        state
      else
        # No more chained events, so lets refresh schedule
        generate_schedule(state)
      end
    }
  end

  @doc "generate the schedule for all zones that need an updated next_occurrence"
  def generate_schedule(state) do
    newschedule = state.schedule
      |> Enum.map(fn {zone, zoneinfo} ->
          if !is_map_key(zoneinfo, :next), do: zone_schedule(state, zone), else: {zone, zoneinfo}
      end)
      |> Enum.into(%{})
    DrizzleWeb.Endpoint.broadcast(@topic, "schedule refreshed", schedule_explained(newschedule))
    state |> Map.merge(%{schedule: newschedule})
  end

  @doc "given the schedule_config stored in state, produce a throw-away schedule for today's events"
  def todays_tasks(state) do
    state.schedule_config
    |> Enum.map(fn {zone, _zoneconfig} -> zone_schedule(state, zone) end)
    |> Enum.into(%{})
  end

  # get an specific zone's schedule
  defp zone_schedule(state, zone) do
    zoneinfo = state |> get_in([:schedule, zone])
    {duration, variance, frequency, trigger_clause} = state |> get_in([:schedule_config, zone])
    #factor = Drizzle.Weather.weather_adjustment_factor() |>IO.inspect(label: "factor")
    factor = 0.5
    dur_millis = duration
      |> parse_duration()
      |> apply_variance(variance, factor)
      |> round()
    freq = frequency
      |> freqexpr()
    trig = trigger_clause
      |> parse_trigger(state.astro)
      |> evtexpr()
    next = next_occurrence(freq, trig)
    {zone, Map.merge(%{dur: dur_millis, freq: freq, trig: trig, next: next},
      # set up a timer if the zone's duration is > 0 and its trigger is not a chain to a previous zone
      (if dur_millis > 0 and elem(trigger_clause, 0) != :chain, do: add_timer(zone, zoneinfo, dur_millis, next), else: %{}))
    }
  end

  @doc "create a timer for a zone"
  def add_timer(zone, zoneinfo, duration_millis, next) do
    if (is_map(zoneinfo) and is_map_key(zoneinfo, :timer)) do
      #IO.puts "skipped adding timer for #{zone} - already exists"
      %{}
    else
      IO.puts "Adding timer for #{zone} at #{next} for #{round(duration_millis/1000)} sec"
      {:ok, timer_ref} = SchedEx.run_at Drizzle.IO, :pulse, [zone, duration_millis, self()], next
      %{timer: timer_ref}
    end
  end

  # TODO: do we want :fixed to mean "ignore weather data", or simply turn off the zone when rain is expected?
  # uncommenting the 1st clause will block ALL zones when weather adjustment factor is 0, regardless of variance requested
  #defp apply_variance(_duration, _variance, 0), do: 0
  defp apply_variance(duration, variance, factor) do
    Timex.Duration.to_milliseconds(duration) * (if variance == :fixed do 1 else factor end)
  end

  # convert duration tuple to Timex.Duration eg {1, :hours} ==> #<Duration(PT1H)>
  def parse_duration({num, units}) when is_number(num) and units in [:hours, :minutes, :seconds] do
    apply(Timex.Duration, String.to_atom("from_#{units}"), [num]) #|> IO.inspect(label: "offset")
  end

  # cron expression for frequency ==> day of week
  defp freqexpr({:every, x, :days}),  do: %{dow_divisor: x}
  defp freqexpr({:on, arr_of_days}),  do: %{dow: Enum.map(arr_of_days, &(Timex.day_to_num(&1)))}
  defp freqexpr({}), do: %{}

  # cron expression for triggers ==> hour+minute
  defp parse_trigger({:chain,   :after, zone}, _astro), do: zone
  defp parse_trigger({:exactly, :at,   event}, astro) when event in [:midnight, :sunrise, :noon, :sunset], do: evttime(event, astro)
  defp parse_trigger({offset, :before, event}, astro), do: evttime(event, astro) |> Timex.subtract(offset |> parse_duration())
  defp parse_trigger({offset, :after,  event}, astro), do: evttime(event, astro) |> Timex.add(offset |> parse_duration())

  # get UTC datetimes for today's astronomical events, only the hour+min part is used
  defp evttime(:midnight, astro), do: Timex.shift(evttime(:noon, astro), hours: 12)
  defp evttime(:sunrise,  astro), do: with {:ok, ret} <- Solarex.Sun.rise(Timex.today(), astro.latitude, astro.longitude), do: ret |> Timex.Timezone.convert("Etc/UTC")
  defp evttime(:noon,     astro), do: with {:ok, ret} <- Solarex.Sun.noon(Timex.today(), astro.latitude, astro.longitude), do: ret |> Timex.Timezone.convert("Etc/UTC")
  defp evttime(:sunset,   astro), do: with {:ok, ret} <- Solarex.Sun.set(Timex.today(),  astro.latitude, astro.longitude), do: ret |> Timex.Timezone.convert("Etc/UTC")
  defp evttime(:now,     _astro), do: Timex.now() # NOTE: should only be used with tests, as this is not an 'anchored' event time that occurs exactly once per day

  defp evtexpr(%DateTime{} = dt), do: %{hour: dt.hour, min: dt.minute, sec: dt.second}
  defp evtexpr(x), do: x

  # for list of days trigger, walk up from the current week up to 1 week later to find a datetime
  def next_occurrence(%{dow: arr}, trig) when is_list(arr) do
    {year, weeknum, _dow} = Timex.iso_triplet(Timex.now)
    for week_advance <- 0..1, day_of_week <- arr do
      Timex.from_iso_triplet({year, weeknum+week_advance, day_of_week}) |> join_date_time(trig)
    end |> Enum.find(fn(candidate) -> candidate |> Timex.after?(Timex.now()) end)
  end
  # for "every X days" trigger, find future date whose day is divisible by X
  def next_occurrence(%{dow_divisor: dd}, trig) do
    for days_advance <- 0..dd do
      Date.utc_today |> join_date_time(trig) |> Timex.shift(days: days_advance)
    end
    |> Enum.find(fn(candidate) ->
      {{_y,_m,d},{_,_,_}} = Timex.to_erl(candidate)
      (candidate |> Timex.after?(Timex.now()) and rem(d, dd)==0
    ) end)
  end
  def next_occurrence(%{}, _), do: nil

  defp join_date_time({y, m, d}, time) do
    {{y, m, d}, {time.hour, time.min, time.sec}} |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
  end
  defp join_date_time(date, time) do
    {:ok, merged} = NaiveDateTime.new(date, Time.from_erl!({time.hour, time.min, time.sec}))
    merged |> DateTime.from_naive!("Etc/UTC")
  end

end
