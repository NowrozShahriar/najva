defmodule Najva.XmppClient.Encryption do
  import Ecto.Query

  alias Najva.Repo
  alias Najva.Accounts.User

  @moduledoc """
  Handles AES-GCM encryption and decryption of passwords using a user-specific key.
  """

  # AES-GCM 256 requires a 32-byte key and specific IV length
  # Additional Authenticated Data for integrity check
  @aad "NajvaAuth"

  def encrypt(plaintext, key_base64) do
    key = Base.decode64!(key_base64)
    # 96-bit IV for GCM
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

    # Return IV + Tag + Ciphertext encoded
    (iv <> tag <> ciphertext) |> Base.encode64()
  end

  def decrypt(ciphertext_base64, key_base64) do
    key = Base.decode64!(key_base64)
    data = Base.decode64!(ciphertext_base64)

    <<iv::binary-12, tag::binary-16, ciphertext::binary>> = data

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      :error -> {:error, :decryption_failed}
      plaintext -> {:ok, plaintext}
    end
  rescue
    _ -> {:error, :invalid_data}
  end

  def get_encryption_key(jid) do
    # Query optimization: We only need the key, not the whole user struct
    query =
      from u in User,
        where: u.jid == ^jid,
        select: u.encryption_key

    Repo.one(query)
  end

  @doc """
  Generates a new AES-256 encryption key and saves it to the user's record.
  Creates a new user if one doesn't exist, otherwise updates the existing record.
  Returns {:ok, key} on success or {:error, reason} on failure.
  """
  def generate_and_update_key(jid) do
    key = :crypto.strong_rand_bytes(32) |> Base.encode64()

    case Repo.get_by(User, jid: jid) do
      nil ->
        # New user - create record with the generated key
        %User{}
        |> User.changeset(%{jid: jid, encryption_key: key})
        |> Repo.insert()
        |> case do
          {:ok, _user} -> {:ok, key}
          {:error, changeset} -> {:error, changeset}
        end

      user ->
        # Existing user - update their key
        user
        |> Ecto.Changeset.change(%{encryption_key: key})
        |> Repo.update()
        |> case do
          {:ok, _user} -> {:ok, key}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end
