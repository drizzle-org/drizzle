defmodule DrizzleUiWeb.PageLive do
  use DrizzleUiWeb, :live_view

  @pubsub_topic "drizzle"

  @impl true
  def mount(_params, _session, socket) do
    IO.puts "PageLive.mount"
    DrizzleUiWeb.Endpoint.subscribe(@pubsub_topic)
    zones = Drizzle.IO.zonestate()
    #IO.inspect zones
    {:ok, assign(socket, query: "", results: %{}, zones: zones)}
  end

  @impl true
  def handle_event("suggest", %{"q" => query}, socket) do
    {:noreply, assign(socket, results: search(query), query: query)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    case search(query) do
      %{^query => vsn} ->
        {:noreply, redirect(socket, external: "https://hexdocs.pm/#{query}/#{vsn}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "No dependencies found matching \"#{query}\"")
         |> assign(results: %{}, query: query)}
    end
  end

  def handle_event("manual zone control", assigns, socket) do
    apply(Drizzle.IO, String.to_atom(assigns["cmd"]), [String.to_atom(assigns["zone"])])
    {:noreply, socket}
  end

  def handle_info(%{event: "zone status change", payload: zoneinfo}, socket) do
    newzones = put_in(socket.assigns.zones, [zoneinfo.zone, :currstate], zoneinfo.newstate)
    #IO.puts "HANDLE BROADCAST FOR #{@pubsub_topic}, #{inspect(newzones)}"
    {:noreply, socket |> assign(:zones, newzones)}
  end

  defp search(query) do
    #if not DrizzleUiWeb.Endpoint.config(:code_reloader) do
    #  raise "action disabled when not in development"
    #end

    for {app, desc, vsn} <- Application.started_applications(),
        app = to_string(app),
        String.starts_with?(app, query) and not List.starts_with?(desc, ~c"ERTS"),
        into: %{},
        do: {app, vsn}
  end

end
