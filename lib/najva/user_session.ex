defmodule Najva.UserSession do
  use GenServer, restart: :transient

  alias Najva.{Ejabberd, UserSessionRegistry, UserSessionSupervisor, StanzaHandler}
  alias Najva.Profiles.PresenceBuffer

  @idle_timeout 30_000

  @doc """
  Ensures a session GenServer is started for the user and returns the associated JID.
  The calling process will be monitored, and the session will be closed after a 30s
  idle period with no subscribers.
  """
  def get_jid(user_id) do
    case ensure_started(user_id) do
      {:ok, pid} -> GenServer.call(pid, :get_jid)
      error -> error
    end
  end

  def ensure_started(user_id) do
    case Horde.Registry.whereis_name({UserSessionRegistry, {__MODULE__, user_id}}) do
      :undefined ->
        case Horde.DynamicSupervisor.start_child(UserSessionSupervisor, %{
               id: {__MODULE__, user_id},
               start: {__MODULE__, :start_link, [[user_id: user_id]]},
               restart: :transient
             }) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end

      pid ->
        {:ok, pid}
    end
  end

  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(user_id))
  end

  def via_tuple(user_id) do
    {:via, Horde.Registry, {UserSessionRegistry, {__MODULE__, user_id}}}
  end

  # Callbacks

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    jid = %{
      sid: Ejabberd.make_sid(),
      username: user_id,
      res: Integer.to_string(System.os_time(), 36)
    }

    Ejabberd.open_session(jid)
    PresenceBuffer.set_presence(user_id, true)

    {:ok, %{user_id: user_id, jid: jid, monitors: %{}, timer_ref: nil}}
  end

  @impl true
  def handle_call(:get_jid, {pid, _ref}, state) do
    state =
      if Enum.find(state.monitors, fn {_, monitored_pid} -> monitored_pid == pid end) do
        state
      else
        if state.timer_ref do
          Process.cancel_timer(state.timer_ref)
        end

        ref = Process.monitor(pid)
        %{state | monitors: Map.put(state.monitors, ref, pid), timer_ref: nil}
      end

    {:reply, state.jid, state}
  end

  @impl true
  def handle_info({:route, message}, state) do
    StanzaHandler.handle_message(message, true)
    {:noreply, state}
  end

  @impl true
  def handle_info({:exit, _reason}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    new_monitors = Map.delete(state.monitors, ref)

    new_state =
      if map_size(new_monitors) == 0 do
        timer_ref = Process.send_after(self(), :stop_idle, @idle_timeout)
        %{state | monitors: new_monitors, timer_ref: timer_ref}
      else
        %{state | monitors: new_monitors}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:stop_idle, state) do
    if map_size(state.monitors) == 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, %{user_id: user_id, jid: jid}) do
    Ejabberd.close_session(jid)
    PresenceBuffer.set_presence(user_id, false)
  end
end
