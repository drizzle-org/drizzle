defmodule Drizzle.Types.WateringTime do
  use Ecto.Type

  def cast({start, stop} = time) do
    with :ok <- check_time(start),
         :ok <- check_time(stop) do
      {:ok, time}
    else
      _ -> :error
    end
  end

  def cast(%{
        "start" => %{"hour" => s_h, "minute" => s_m},
        "end" => %{"hour" => e_h, "minute" => e_m}
      }) do
    with {s_h, ""} <- Integer.parse(s_h),
         {s_m, ""} <- Integer.parse(s_m),
         {e_h, ""} <- Integer.parse(e_h),
         {e_m, ""} <- Integer.parse(e_m) do
      s_digits = prep_digits(s_h) ++ prep_digits(s_m)
      e_digits = prep_digits(e_h) ++ prep_digits(e_m)

      cast({Integer.undigits(s_digits), Integer.undigits(e_digits)})
    else
      _ -> :error
    end
  end

  def cast(_), do: :error

  def dump(val), do: {:ok, val}
  def load(val), do: {:ok, val}

  def type(), do: :integer

  defp check_time(time) do
    Integer.digits(time)
    |> Enum.split(-2)
    |> Tuple.to_list()
    |> Enum.map(&Integer.undigits/1)
    |> case do
      [hh, mm] when hh in 0..23 and mm in 0..59 -> :ok
      _ -> :invalid_time
    end
  end

  def prep_digits(d) when d > 9, do: Integer.digits(d)
  def prep_digits(d), do: [0, d]
end
