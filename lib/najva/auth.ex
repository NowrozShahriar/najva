defmodule Najva.Auth do
  alias Najva.Repo
  alias Najva.Accounts.User
  # PATH A: Restore Session
  # Just ask the GenServer. It handles the "Cache check -> Decrypt -> Cache update" logic.
  def restore_session(jid, encrypted_password) do
    case :global.whereis_name(jid) do
      pid when is_pid(pid) ->
        case GenServer.call(pid, {:verify_session, encrypted_password}) do
          :ok -> {:ok, :running}
          _ -> {:error, :invalid_session}
        end

      nil ->
        nil
        # Cold start logic remains the same (Fetch key -> Decrypt -> Start GS)
        # restore_from_cold_storage(jid, encrypted_password)
    end
  end

  # PATH B: Manual Login
  def login(jid, password) do
    case :global.whereis_name(jid) do
      pid when is_pid(pid) ->
        # GS is running.
        # 1. Generate a NEW unique ciphertext for this specific device.
        key = get_user_encryption_key(jid)
        new_ciphertext = Najva.Auth.Encryption.encrypt(password, key)

        # 2. Tell GenServer to trust this new token
        GenServer.call(pid, {:add_session_token, new_ciphertext})

        # 3. Give it to the user
        {:ok, new_ciphertext}

      nil ->
        nil
        # GS not running. Start fresh.
        # attempt_start_login(jid, password)
    end
  end

  # ... helpers (restore_from_cold_storage, attempt_start_login) remain mostly same ...
  # Ensure attempt_start_login passes the initial ciphertext to start_link
  defp get_user_encryption_key(jid) do
    import Ecto.Query

    # Query optimization: We only need the key, not the whole user struct
    query =
      from u in Najva.Accounts.User,
        where: u.jid == ^jid,
        select: u.encryption_key

    Najva.Repo.one(query)
  end

  defp save_user_encryption_key(jid, key) do
    # Find the user and update their key
    case Najva.Repo.get_by(Najva.Accounts.User, jid: jid) do
      nil ->
        # Should not happen if user just logged in, but handle gracefully
        {:error, :user_not_found}

      user ->
        user
        |> Ecto.Changeset.change(%{encryption_key: key})
        |> Najva.Repo.update()
    end
  end
end
