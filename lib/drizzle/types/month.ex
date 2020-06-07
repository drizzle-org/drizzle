defmodule Drizzle.Types.Month do
  use Ecto.Type

  @months [
    "january",
    "february",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december"
  ]

  @expected Enum.map(@months, &String.to_atom(String.slice(&1, 0..2)))

  @allowed [
             # november
             @months,
             # November
             Enum.map(@months, &String.capitalize/1),
             # :november
             Enum.map(@months, &String.to_atom/1),
             # :November
             Enum.map(@months, &String.to_atom(String.capitalize(&1))),
             # nov
             Enum.map(@expected, &to_string/1)
           ]
           |> List.flatten()

  def __options__(), do: Enum.zip(@months, @expected)

  def type(), do: :atom

  def cast(val) when val in @expected, do: {:ok, val}

  def cast(val) when val in @allowed do
    casted =
      to_string(val)
      |> String.downcase()
      |> String.slice(0..2)
      |> String.to_existing_atom()

    {:ok, casted}
  end

  def cast(_), do: :error

  def dump(val), do: {:ok, val}
  def load(val), do: {:ok, val}
end
