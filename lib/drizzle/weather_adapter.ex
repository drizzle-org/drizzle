defmodule Drizzle.WeatherAdapter do
  @type temperature :: Integer.t()
  @type precipitation :: number()
  @type precipitation_probability :: number()
  @type wind_speed :: number()
  @type forecast_data ::
          {temperature(), precipitation(), precipitation_probability(), wind_speed()}

  @doc """
  Fetch the forecast as a list of hourly reports.

  Only the first 24 reports of the returned list will be taken.
  Reports should be in the form of a tuple with the following structure:

  ```
  {temperature, precipitation, precipitation_probability, wind_speed}
  ```
  """
  @callback forecast() :: [forecast_data()]
end
