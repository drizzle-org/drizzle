defmodule Drizzle.Weather do
  @moduledoc """
  This module handles getting the weather forecast.
  """

  @winter_months Application.get_env(:drizzle, :winter_months, [])
  @temp_units Application.get_env(:drizzle, :temp_units, :f)
  @soil_moisture_sensor Application.get_env(:drizzle, :soil_moisture_sensor, nil)
  @default_adapter Drizzle.WeatherAdapter.ClimaCell

  @doc """
  weather_adjustment_factor/0 determines adjustments to make to watering time
  based on the atmospheric conditions.
  """
  @spec weather_adjustment_factor() :: float() | {:error, String.t()}
  def weather_adjustment_factor do
    if month_as_atom(DateTime.utc_now().month) in @winter_months do
      0
    else
      {low, high, precipitation} =
        Drizzle.WeatherData.current_state()
        |> Enum.filter(&(!is_nil(&1)))
        |> weather_info()

      temperature_adjustment(low, high)
      |> Kernel.*(precipitation_adjustment(precipitation))
      |> Kernel.*(soil_moisture_adjustment(@soil_moisture_sensor))
    end
  end

  def get_todays_forecast do
    weather_adapter().forecast()
    |> Enum.slice(0..23)
    |> Drizzle.WeatherData.update()
  end

  defp temperature_adjustment(low, high) do
    cond do
      is_nil(low) -> 0
      is_nil(high) -> 0
      low <= low_temp() -> 0
      high >= high_temp() -> 1.33
      true -> 1
    end
  end

  defp precipitation_adjustment(prec) when prec >= 1.0, do: 0
  defp precipitation_adjustment(prec) when prec >= 0.5, do: 0.5
  defp precipitation_adjustment(prec) when prec >= 0.25, do: 0.75
  defp precipitation_adjustment(_prec), do: 1

  defp soil_moisture_adjustment(nil), do: 1

  defp soil_moisture_adjustment(%{pin: pin, min: min, max: max}) do
    # check pin for sensor reading.
    moisture = Drizzle.IO.read_soil_moisture(pin)

    # need to calibrate against a non-zero min
    moisture_delta = max - min
    moisture = moisture - min

    case moisture do
      val when val > moisture_delta * 0.9 -> 0.0
      val when val > moisture_delta * 0.85 -> 0.1
      val when val > moisture_delta * 0.8 -> 0.2
      val when val > moisture_delta * 0.75 -> 0.45
      val when val > moisture_delta * 0.7 -> 0.65
      val when val > moisture_delta * 0.65 -> 0.8
      val when val > moisture_delta * 0.6 -> 0.9
      val when val > moisture_delta * 0.55 -> 0.95
      val when val > moisture_delta * 0.5 -> 1.0
      val when val > moisture_delta * 0.45 -> 1.05
      val when val > moisture_delta * 0.4 -> 1.1
      val when val > moisture_delta * 0.35 -> 1.2
      val when val > moisture_delta * 0.3 -> 1.35
      val when val > moisture_delta * 0.85 -> 1.55
      val when val > moisture_delta * 0.2 -> 1.80
      val when val > moisture_delta * 0.85 -> 1.90
      val when val > moisture_delta * 0.1 -> 2.0
      _ -> 2.0
    end
  end

  # Used when application has just started up
  defp weather_info([]), do: {nil, nil, 0}

  defp weather_info(data) do
    with {cumulative_amount, cumulative_percent} <-
           Enum.reduce(data, {0, 0}, fn {_, am, pr, _}, {acc_a, acc_b} ->
             {acc_a + am, acc_b + pr}
           end),
         {low, high} <- Enum.min_max_by(data, fn {temp, _, _, _} -> temp end),
         rainfall <- cumulative_amount * cumulative_percent do
      {low_temp, _, _, _} = low
      {high_temp, _, _, _} = high
      {low_temp, high_temp, rainfall}
    else
      _err -> {:error, "unknown error"}
    end
  end

  defp month_as_atom(num) do
    months_map = %{
      1 => :jan,
      2 => :feb,
      3 => :mar,
      4 => :apr,
      5 => :may,
      6 => :jun,
      7 => :jul,
      8 => :aug,
      9 => :sep,
      10 => :oct,
      11 => :nov,
      12 => :dec
    }

    Map.get(months_map, num)
  end

  defp low_temp do
    case @temp_units do
      :f -> 32
      :c -> 0
    end
  end

  defp high_temp do
    case @temp_units do
      :f -> 90
      :c -> 32
    end
  end

  defp weather_adapter do
    Application.get_env(:drizzle, :weather_adapter, @default_adapter)
  end
end
