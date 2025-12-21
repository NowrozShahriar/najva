defmodule Najva.Auth do
  # PATH A: With Cookies
  # Just ask the GenServer. It handles the "Cache check -> Decrypt -> Cache update" logic.
  def restore_session(jid, encrypted_password) do
    case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
      [{pid, _}] ->
        GenServer.call(pid, {:verify_session, encrypted_password})

      [] ->
        nil
    end
  end

  # PATH B: Without Cookies
  def login(jid, password) do
    # Generate a NEW unique ciphertext for this specific device.
    case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
      [{pid, _}] ->
        # GS is running.
        # 1. Tell GenServer to provide new token if password matches.
        GenServer.call(pid, {:get_new_ciphertext, password})

      [] ->
        # GS not running. Start fresh.
        Najva.HordeSupervisor.start_client(jid, password, self())

        receive do
          {:authenticated, new_ciphertext} ->
            {:ok, new_ciphertext}
        after
          15_000 ->
            {:error, :timeout}
        end
    end
  end
end
