defmodule Najva.Ejabberd.ModNajva.Interceptor do
  def on_packet_intercept(packet) do
    case packet do
      msg when elem(msg, 0) == :message ->
        IO.inspect(packet, label: "Intercepted message")

      presence when elem(presence, 0) == :presence ->
        IO.inspect(packet, label: "Intercepted presence")

      _ ->
        IO.inspect(packet, label: "Intercepted packet")
    end

    packet
  end
end
