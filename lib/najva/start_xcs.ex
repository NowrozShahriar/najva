defmodule Najva.StartXcs do
  def start() do
    Najva.XmppClient.start_link([jid: "najva_test0@conversations.im", password: "random_password", host: "conversations.im", port: 5222])
  end
end
