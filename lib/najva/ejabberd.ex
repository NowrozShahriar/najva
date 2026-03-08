defmodule Najva.Ejabberd do
  def register(username, host, password), do: :ejabberd_admin.register(username, host, password)
  def unregister(username, host), do: :ejabberd_admin.unregister(username, host)

  def set_password(username, host, password),
    do: :ejabberd_auth.set_password(username, host, password)

  def open_session(%{sid: sid, username: username, host: host, res: res}),
    do: :ejabberd_sm.open_session(sid, username, host, res, [])

  def close_session(%{sid: sid, username: username, host: host, res: res}),
    do: :ejabberd_sm.close_session(sid, username, host, res)

  def send_presence(%{username: username, host: host, res: res}) do
    :ejabberd_router.route(
      {:jid, username, host, res, username, host, res},
      {:jid, "", host, "", "", host, ""},
      {
        :xmlel,
        "presence",
        [{"from", "#{username}@#{host}/#{res}"}],
        []
      }
    )
  end
end
