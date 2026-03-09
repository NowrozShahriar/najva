defmodule Najva.Ejabberd.ModNajva.IqHandler do
  def handle_iq(iq, _from, _to, _host, _opts) do
    IO.inspect(iq, label: "Handle IQ")
    :ok
  end
end
