defmodule Najva.Ejabberd do
  @host %Najva{}.host

  def register(username, password),
    do:
      :ejabberd_admin.register(username, @host, password)
      |> IO.inspect(label: "Registered #{username}@#{@host}")

  def unregister(username),
    do:
      :ejabberd_admin.unregister(username, @host)
      |> IO.inspect(label: "Unregistered #{username}@#{@host}")

  def set_password(username, password),
    do:
      :ejabberd_auth.set_password(username, @host, password)
      |> IO.inspect(label: "Set new password for #{username}@#{@host}")

  def open_session(%{sid: sid, username: username, res: res}),
    do:
      :ejabberd_sm.open_session(sid, username, @host, res, 10, [])
      |> IO.inspect(label: "Opened session for #{username}@#{@host}/#{res}")

  def close_session(%{sid: sid, username: username, res: res}),
    do:
      :ejabberd_sm.close_session(sid, username, @host, res)
      |> IO.inspect(label: "Closed session for #{username}@#{@host}/#{res}")

  def make_sid, do: :ejabberd_sm.make_sid()
  # |> IO.inspect(label: "Make sid")

  # def send_presence(%{username: username, res: res}) do
  #   :ejabberd_router.route(
  #     {:jid, username, @host, res, username, @host, res},
  #     {:jid, "", @host, "", "", @host, ""},
  #     {
  #       :xmlel,
  #       "presence",
  #       [{"from", "#{username}@#{@host}/#{res}"}],
  #       []
  #     }
  #   )
  #   |> IO.inspect(label: "Send presence for #{username}@#{@host}/#{res}")
  # end

  def send_message(
        %{username: username, res: res},
        peer,
        peer_host,
        msg_id,
        time,
        content
      ) do
    packet =
      {:xmlel, "message",
       [
         {"from", "#{username}@#{@host}/#{res}"},
         {"to",
          if peer_host != "" do
            "#{peer}@#{peer_host}"
          else
            "#{peer}@#{@host}"
          end}
       ],
       [
         {:xmlel, "n", [{"xmlns", "najva:v1"}, {"type", "chat"}],
          [{:xmlel, "content", [{"time", time}, {"id", msg_id}], [xmlcdata: content]}]}
       ]}

    :ejabberd_router.route(
      {:jid, username, @host, res, username, @host, res},
      {:jid, peer, peer_host, "", peer, peer_host, ""},
      packet
    )
  end
end
