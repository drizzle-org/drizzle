defmodule DrizzleWeb.PageLive do
  use DrizzleWeb, :live_view

  @pubsub_topic "drizzle"

  @impl true
  def mount(_params, _session, socket) do
    DrizzleWeb.Endpoint.subscribe(@pubsub_topic)
    zones = Drizzle.IO.zonestate()
    {:ok, assign(socket, query: "", results: %{}, schedule: Drizzle.Scheduler.explain_schedule(), zones: zones)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("manual zone control", assigns, socket) do
    apply(Drizzle.IO, String.to_atom(assigns["cmd"]), [String.to_atom(assigns["zone"])])
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "zone status change", payload: zoneinfo}, socket) do
    newzones = put_in(socket.assigns.zones, [zoneinfo.zone, :currstate], zoneinfo.newstate)
    {:noreply, socket |> assign(:zones, newzones)}
  end

  def handle_info(%{event: "schedule refreshed", payload: newschedule}, socket) do
    {:noreply, socket |> assign(:schedule, newschedule)}
  end

end
