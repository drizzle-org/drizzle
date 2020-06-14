defmodule Drizzle.Types.SchedulerConfig do
  use Ecto.Type

  def cast(value) do
    IO.inspect(value, label: "cast")
    {:ok, value}
  end
  def cast(_), do: :error

  def dump(val), do: {:ok, val}
  def load(val), do: {:ok, val}

  def type(), do: :map
end
