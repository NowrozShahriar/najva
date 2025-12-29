defmodule Najva.Auth do
  alias Najva.XmppClient.Encryption
  # PATH A: With Cookies
  # Just ask the GenServer. It handles the "Cache check -> Decrypt -> Cache update" logic.
  def restore_session(jid, ciphertext) do
    case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
      [{pid, _}] ->
        GenServer.call(pid, {:verify_session, ciphertext})

      [] ->
        {:ok, plaintext} =
          case Encryption.get_encryption_key(jid) do
            nil -> {:error, :user_not_found}
            key -> Encryption.decrypt(key, ciphertext)
          end

        ########## here we need to pass the already existing ciphertext to the gen server instead of the pid as were only restoring the session.
        Najva.HordeSupervisor.start_client(jid, plaintext, self())

        receive do
          {:authenticated, new_ciphertext} ->
            {:ok, new_ciphertext}
        after
          15_000 ->
            {:error, :timeout}
        end
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
