defmodule Najva.Auth do
  alias Najva.XmppClient.Encryption
  alias Phoenix.PubSub

  # PATH A: With Cookies (restoring session using ciphertext)
  def restore_session(jid, ciphertext) do
    case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
      [{pid, _}] ->
        GenServer.call(pid, {:verify_session, ciphertext})

      [] ->
        # Decrypt ciphertext before starting the GenServer
        case Encryption.get_encryption_key(jid) do
          nil ->
            {:error, :user_not_found}

          key ->
            case Encryption.decrypt(key, ciphertext) do
              {:ok, password} ->
                PubSub.subscribe(Najva.PubSub, jid)
                Najva.HordeSupervisor.start_client(jid, password)

                receive do
                  :authenticated ->
                    PubSub.unsubscribe(Najva.PubSub, jid)
                    :ok
                after
                  15_000 ->
                    {:error, :timeout}
                end

              {:error, reason} ->
                {:error, reason}
            end
        end
    end
  end

  # PATH B: Without Cookies (fresh login with password)
  def login(jid, password) do
    # Generate a NEW unique ciphertext for this specific device.
    case Horde.Registry.lookup(Najva.HordeRegistry, jid) do
      [{pid, _}] ->
        # GS is running.
        # 1. Tell GenServer to provide new token if password matches.
        GenServer.call(pid, {:get_new_ciphertext, password})

      [] ->
        # GS not running. Start fresh.
        # Subscribe to PubSub for authentication notification
        PubSub.subscribe(Najva.PubSub, jid)
        Najva.HordeSupervisor.start_client(jid, password)

        receive do
          {:authenticated, new_ciphertext} ->
            PubSub.unsubscribe(Najva.PubSub, jid)
            {:ok, new_ciphertext}
        after
          15_000 ->
            {:error, :timeout}
        end
    end
  end
end
