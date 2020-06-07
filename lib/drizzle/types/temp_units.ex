defmodule Drizzle.Types.TempUnits do
  use Ecto.Type

  @units_map %{
    f: [:f, :us, :farenheit, "f", "F", "US", "Farenheit"],
    c: [:c, :si, "c", "C", "SI"]
  }

  def type(), do: :f

  def cast(val) do
    Enum.find_value(@units_map, fn {k, v} -> if val in v, do: k end)
    |> case do
      nil -> :error
      result -> {:ok, result}
    end
  end

  def dump(val), do: {:ok, val}
  def load(val), do: {:ok, val}
end
