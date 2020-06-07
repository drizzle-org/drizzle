defmodule Drizzle.Scheduler do
  use GenServer

  @schedule_config %{
    #        duration        variance   frequency                   trigger_clause
    #                                                        offset      after/before  condition
    zone1: {{5,  :minutes}, :fixed,    {:every, 2, :days}, {{3, :hours},   :before, :sunrise}},
    #zone2: {{20, :minutes}, :variable, {:every, 2, :days}, {{3.5, :hours}, :after,  :midnight}},
    zone2: {{10, :seconds}, :variable, {:every, 1, :days}, {{3, :seconds}, :after,  :now}},
    zone3: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone2}},
    zone4: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone3}},
    zone5: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone4}},
    zone6: {{10, :seconds}, :variable, {},                 {:chain,        :after,  :zone5}},
    zone7: {{20, :minutes}, :variable, {:every, 3, :days}, {:exactly,      :at,     :noon}},
    zone8: {{10, :minutes}, :fixed,    {:on, [:mon, :fri]}, {{30, :minutes}, :after, :sunset}}
  }

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      astro: Application.get_env(:drizzle, :location) |> Map.new(fn {k, v} -> {k, String.to_float(v)} end),
      schedule_config: @schedule_config},
    name: DrizzleScheduler)
  end

  def init(initstate), do: {:ok, Map.merge(initstate, %{schedule: todays_tasks(initstate)})}

  @doc "returns the current schedule, including next occurences for chained zones"
  def explain_schedule() do
    sch = GenServer.call(DrizzleScheduler, :get_schedule)
    sch |> Enum.map(fn {zone, zinfo} -> {zone,
      duration_seconds: round(sch[zone].dur/1000),
      next_occurrence: explain_zone(sch, zone)
    } end)
  end

  def explain_zone(sch, zone) do
    sch[zone].next || Timex.add(explain_zone(sch, sch[zone].trig), Timex.Duration.from_milliseconds(sch[zone].dur))
  end

  @doc "recalculate sunrise and sunset every midnight"
  def handle_cast(:scheduler_config_changed, state), do: {:noreply, generate_schedule(state)}
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

  def generate_schedule(state) do
    state
    |> Map.merge(%{schedule:
      state.schedule
      |> Enum.map(fn {zone, zoneinfo} ->
            if !is_map_key(zoneinfo, :next), do: zone_schedule(state, zone), else: {zone, zoneinfo}
        end)
      |> Enum.into(%{})
    })
  end

  @doc "given the schedule_config stored in state, produce a throw-away schedule for today's events"
  def todays_tasks(state) do
    state.schedule_config
    |> Enum.map(fn {zone, _zoneconfig} -> zone_schedule(state, zone) end)
    |> Enum.into(%{})
  end

  @doc "get an individual zone's schedule"
  defp zone_schedule(state, zone) do
    zoneinfo = state |> get_in([:schedule, zone])
    {duration, variance, frequency, trigger_clause} = state |> get_in([:schedule_config, zone])
    #factor = Drizzle.Weather.weather_adjustment_factor() |>IO.inspect(label: "factor")
    factor = 0.1
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
