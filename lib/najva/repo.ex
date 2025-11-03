defmodule Najva.Repo do
  use Ecto.Repo,
    otp_app: :najva,
    adapter: Ecto.Adapters.Postgres
end
