defmodule DrizzleUiWeb.SettingsComponent do
  use DrizzleUiWeb, :live_component

  alias Drizzle.Settings

  @impl true
  def update(assigns, socket) do
    changeset = Settings.changeset(Settings.read(), %{})
    {:ok, assign(socket, Map.put(assigns, :changeset, changeset))}
  end

  @impl true
  def handle_event("import_config", _, socket) do
    config = Map.new(Application.get_all_env(:drizzle))

    attrs = Map.merge(config, Map.get(config, :watering_times, %{}))
    |> Map.merge(Map.get(config, :location, %{}))

    changeset =
      socket.assigns.changeset
      |> Settings.changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", _, socket) do
    case Settings.save(socket.assigns.changeset) do
      :ok ->
        {:noreply, socket
      |> put_flash(:info, "Settings saved")
    |> push_redirect(to: socket.assigns.return_to)}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", %{"settings" => attrs}, socket) do
    changeset =
      socket.assigns.changeset
      |> Settings.changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp format_watering_time(time) do
    {s_h, s_m} = Integer.digits(time)
    |> Enum.split(-2)

    %{"hour" => Integer.undigits(s_h), "minute" => Integer.undigits(s_m)}
  end

  defp has_month?(val, changeset) do
    val in Ecto.Changeset.get_field(changeset, :winter_months)
  end

  defp watering_times(key, changeset) do
    [st, et] = Ecto.Changeset.get_field(changeset, key)
    |> Tuple.to_list()
    |> Enum.map(&format_watering_time/1)

    [{"start", st}, {"end", et}]
  end
end
