defmodule DrizzleWeb.ScheduleLive do
  use DrizzleWeb, :live_view

  @pubsub_topic "drizzle"

  @impl true
  def mount(_params, _session, socket) do
    DrizzleWeb.Endpoint.subscribe(@pubsub_topic)
    zones = Drizzle.IO.zonestate()
    {:ok, assign(socket, query: "", results: %{}, schedule_config: Drizzle.Scheduler.get_schedule_config())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event(_,_,socket), do: {:noreply, socket}

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def render_duration(assigns, {dur_value, dur_unit}) do
    ~L"""
      <input name="dur_value" value="<%= dur_value %>" maxlength="4" size="1"/>
      <select name="dur_unit" id="dur_unit">
        <%= options_for_select(["seconds": "seconds", "minutes": "minutes"], dur_unit) %>
      </select>
    """
  end

  def render_variance(assigns, variance) do
    ~L"""
      <select name="variance" id="variance">
        <%= options_for_select(["fixed": "fixed", "variable": "variable"], variance) %>
      </select>
    """
  end

  def render_frequency(assigns, {freq_base, freq_val, freq_unit}) do
    ~L"""
      <select name="freq_base" id="freq_base">
        <%= options_for_select(["n/a": "", "every": "every", "on": "on"], freq_base) %>
      </select>
      <input name="freq_value" value="<%= freq_val %>" maxlength="4" size="1"/>
      <select name="freq_unit" id="freq_unit">
        <%= options_for_select(["n/a": "", "hours": "hours", "days": "days"], freq_unit) %>
      </select>
    """
  end
  def render_frequency(assigns, _), do:  ~L"n/a"

  # {:chain,  :after,  :zone2}
  def render_trigger(assigns, {:chain, :after, zone}) do
    ~L"<i>chain after <%=zone%></i>"
  end

  #{3, :hours},   :before, :sunrise}
  def render_trigger(assigns, {offset, after_before, condition}) do
    ~L"""
    <%= render_time_tuple(assigns, :trigger, offset) %>
    <select name="trigger_afterbefore" id="trigger_afterbefore">
      <%= options_for_select(["after": "after", "before": "before"], after_before) %>
    </select>
    <select name="trigger_condition" id="trigger_condition">
      <%= options_for_select(["midnight", "sunrise", "noon", "sunset"], condition) %>
    </select>
    """
  end

  def render_time_tuple(assigns, elemid, {offset_value, offset_unit}) do
    ~L"""
      <input name="<%=elemid%>_value" value="<%= offset_value %>" maxlength="4" size="1"/>
      <select name="<%=elemid%>_unit">
        <%= options_for_select(["seconds": "seconds", "minutes": "minutes"], offset_unit) %>
      </select>
    """
  end
  def render_time_tuple(assigns, elemid, other), do: other

end
