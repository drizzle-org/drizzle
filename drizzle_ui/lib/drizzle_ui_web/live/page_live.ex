defmodule DrizzleUiWeb.PageLive do
  use DrizzleUiWeb, :live_view

  @pubsub_topic "drizzle"

  @impl true
  def mount(_params, _session, socket) do
    DrizzleUiWeb.Endpoint.subscribe(@pubsub_topic)
    zones = Drizzle.IO.zonestate()
    {:ok, assign(socket, query: "", results: %{}, zones: zones)}
  end

  def handle_event("manual zone control", assigns, socket) do
    apply(Drizzle.IO, String.to_atom(assigns["cmd"]), [String.to_atom(assigns["zone"])])
    {:noreply, socket}
  end

  def handle_info(%{event: "zone status change", payload: zoneinfo}, socket) do
    newzones = put_in(socket.assigns.zones, [zoneinfo.zone, :currstate], zoneinfo.newstate)
    {:noreply, socket |> assign(:zones, newzones)}
  end

end
