defmodule Drizzle.WeatherAdapter.ClimaCell do
  @moduledoc """
  Interface for the ClimaCell API
  """
  @behaviour Drizzle.WeatherAdapter

  alias Drizzle.{HTTP, Settings}

  @api_key Application.get_env(:drizzle, :climacell_api_key)

  def forecast do
    build_url()
    |> HTTP.get()
    |> parse_response()
  end

  defp api_key, do: @api_key
  defp fields, do: "temp,wind_speed,precipitation,precipitation_probability"
  defp start_time, do: "now"

  defp end_time do
    # Create an ISO8601 formatted time for 24 hours from now
    DateTime.utc_now()
    |> DateTime.add(86400, :second)
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp temp_units do
    case Settings.temp_units() do
      units when units in [:f, :us, :farenheit] -> "us"
      _ -> "si"
    end
  end

  defp build_url do
    "https://api.climacell.co/v3/weather/forecast/hourly" <>
      "?lat=#{Settings.latitude()}" <>
      "&lon=#{Settings.longitude()}" <>
      "&unit_system=#{temp_units()}" <>
      "&start_time=#{start_time()}" <>
      "&end_time=#{end_time()}" <>
      "&fields=#{fields()}" <>
      "&apikey=#{api_key()}"
  end

  defp parse_response(:error), do: []

  defp parse_response({:ok, %{body: body, status: 200}}) do
    body
    |> Jason.decode!()
    |> Enum.map(fn data ->
      {normalized_temp(data), normalized_precipitation(data),
       normalized_precipitation_probability(data), normalized_wind_speed(data)}
    end)
  end

  defp normalized_temp(%{"temp" => %{"value" => temp}}), do: temp
  defp normalized_precipitation(%{"precipitation" => %{"value" => inches}}), do: inches

  defp normalized_precipitation_probability(%{
         "precipitation_probability" => %{"value" => percent}
       }),
       do: percent / 100

  defp normalized_wind_speed(%{"wind_speed" => %{"value" => wind_speed}}), do: wind_speed
end
