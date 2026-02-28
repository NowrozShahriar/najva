defmodule Najva.Accounts.UserNotifier do
  import Swoosh.Email

  alias Najva.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Najva", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_confirm_email_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.username},

    To confirm this email for your account visit the URL below:

    #{url}

    If you didn't request this change, please ignore.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.username},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore.

    ==============================
    """)
  end
end
