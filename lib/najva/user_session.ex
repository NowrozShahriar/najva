defmodule Najva.UserSession do
  use GenServer, restart: :transient

  alias Najva.{Ejabberd, UserSessionRegistry, UserSessionSupervisor, StanzaHandler}

  @doc """
  Ensures a session GenServer is started for the user and returns the associated JID.
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

    {:ok, %{user_id: user_id, jid: jid}}
  end

  @impl true
  def handle_call(:get_jid, _from, %{jid: jid} = state) do
    {:reply, jid, state}
  end

  @impl true
  def handle_info({:route, message}, state) do
    StanzaHandler.handle_message(message, true)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{jid: jid}) do
    Ejabberd.close_session(jid)
    :ok
  end
end
