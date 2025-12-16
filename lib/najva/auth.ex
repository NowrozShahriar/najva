defmodule Najva.Auth do
  # PATH A: With Cookies
  # Just ask the GenServer. It handles the "Cache check -> Decrypt -> Cache update" logic.
  def restore_session(jid, encrypted_password) do
    case :global.whereis_name(jid) do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:verify_session, encrypted_password})

      :undefined ->
        nil
    end
  end

  # PATH B: Without Cookies
  def login(jid, password) do
    # Generate a NEW unique ciphertext for this specific device.
    case :global.whereis_name(jid) do
      pid when is_pid(pid) ->
        # GS is running.
        # 1. Tell GenServer to trust this new token
        GenServer.call(pid, {:get_new_ciphertext, password})

      :undefined ->
        # GS not running. Start fresh.
        Najva.XmppClient.start_link(%{
          jid: jid,
          password: password
        })
    end
  end
end
