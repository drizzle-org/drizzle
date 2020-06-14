defmodule Drizzle.Settings do
  @doc false
  def child_spec(_arg) do
    dir =
      Application.get_env(:drizzle, :database_dir, "/root")
      |> Path.join("settings")

    %{id: __MODULE__, start: {CubDB, :start_link, [[data_dir: dir, name: __MODULE__]]}}
  end

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  alias Drizzle.Types.{Month, TempUnits, SchedulerConfig, WateringTime}

  embedded_schema do
    field(:latitude)
    field(:longitude)
    field(:utc_offset, :integer, default: 0)
    field(:winter_months, {:array, Month}, default: [])
    field(:morning, WateringTime, default: {300, 600})
    field(:evening, WateringTime, default: {2100, 2300})
    field(:temp_units, TempUnits, default: :f)
    field(:scheduler_config, SchedulerConfig, default: Drizzle.Scheduler.default_config())
  end

  # Create getter functions for each settings field
  for {field, _type} <- @ecto_fields do
    def unquote(field)(), do: CubDB.get(__MODULE__, unquote(field))
  end

  def available_watering_times do
    CubDB.get_multi(__MODULE__, [:morning, :evening])
  end

  def changeset(settings, attrs) do
    cast(settings, attrs, __schema__(:fields))
  end

  def read() do
    case CubDB.select(__MODULE__) do
      {:ok, settings} -> struct(__MODULE__, settings)
      err -> err
    end
  end

  def save(%{valid?: false} = changeset), do: {:error, changeset}

  def save(%{changes: changes, valid?: true}) do
    CubDB.put_multi(__MODULE__, Map.to_list(changes))
  end

  def save(%__MODULE__{} = settings) do
    settings =
      Map.from_struct(settings)
      |> Map.to_list()
      |> Enum.reject(&elem(&1, 1))

    CubDB.put_multi(__MODULE__, settings)
  end
end
