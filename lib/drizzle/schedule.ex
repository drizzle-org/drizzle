defmodule Drizzle.Schedule do
  @type specifier :: :morning | :evening
  @type zone :: {String.t(), specifier(), non_neg_integer()}
  @type day :: :sun | :mon | :tue | :wed | :thu | :fri | :sat

  @day_keys [:sun, :mon, :tue, :wed, :thu, :fri, :sat]

  def child_spec(_arg) do
    dir =
      Application.get_env(:drizzle, :database_dir, "/root")
      |> Path.join("schedules")

    %{id: __MODULE__, start: {CubDB, :start_link, [[data_dir: dir, name: __MODULE__]]}}
  end

  defdelegate size(db \\ __MODULE__), to: CubDB

  def get(day), do: CubDB.get(__MODULE__, day, [])

  @spec set(day(), zone() | [zone()]) :: :ok | {:invalid_day, day} | {:invalid_zones, [any()]}
  def set(day, _zones) when day not in @day_keys, do: {:invalid_day, day}
  def set(day, zone) when is_tuple(zone), do: set(day, [zone])

  def set(day, zones) when is_list(zones) do
    case Enum.reject(zones, &valid_zone?/1) do
      [] -> CubDB.put(__MODULE__, day, zones)
      bad_zones -> {:invalid_zones, bad_zones}
    end
  end

  def set(_day, bad), do: {:invalid_zones, bad}

  defp valid_zone?({_name, specifier, time}) when specifier in [:morning, :evening] and time > 0,
    do: true

  defp valid_zone?(_zone), do: false
end
