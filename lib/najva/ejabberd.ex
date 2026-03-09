defmodule Najva.Ejabberd do
  def register(username, host, password),
    do:
      :ejabberd_admin.register(username, host, password)
      |> IO.inspect(label: "Register #{username}@#{host}")

  def unregister(username, host),
    do:
      :ejabberd_admin.unregister(username, host)
      |> IO.inspect(label: "Unregister #{username}@#{host}")

  def set_password(username, host, password),
    do:
      :ejabberd_auth.set_password(username, host, password)
      |> IO.inspect(label: "Set password for #{username}@#{host}")

  def open_session(%{sid: sid, username: username, host: host, res: res}),
    do:
      :ejabberd_sm.open_session(sid, username, host, res, [])
      |> IO.inspect(label: "Open session for #{username}@#{host}/#{res}")

  def close_session(%{sid: sid, username: username, host: host, res: res}),
    do:
      :ejabberd_sm.close_session(sid, username, host, res)
      |> IO.inspect(label: "Close session for #{username}@#{host}/#{res}")

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
    |> IO.inspect(label: "Send presence for #{username}@#{host}/#{res}")
  end

  def send_test_message(%{username: username, host: host, res: res}, to_string, body) do
    from_jid = {:jid, username, host, res, username, host, res}
    to_jid = :jid.decode(to_string)

    packet = {
      :xmlel,
      "message",
      [{"type", "chat"}, {"from", :jid.encode(from_jid)}, {"to", to_string}],
      [{:xmlel, "body", [], [{:xmlcdata, body}]}]
    }

    :ejabberd_router.route(from_jid, to_jid, packet)
    |> IO.inspect(label: "Send message for #{username}@#{host}/#{res} to #{to_string}")
  end
end
