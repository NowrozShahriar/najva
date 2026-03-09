defmodule Najva.Ejabberd.ModNajva.Interceptor do
  def on_packet_intercept(packet) do
    IO.inspect(packet, label: "Intercepted packet")
    packet
  end
end
