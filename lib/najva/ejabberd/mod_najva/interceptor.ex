defmodule Najva.Ejabberd.ModNajva.Interceptor do
  def on_packet_intercept(packet) do
    case packet do
      # Match only if it's a message (ignore IQ/Presence)
      msg when elem(msg, 0) == :message ->
        IO.inspect(packet, label: "Intercepted message")

      # handle_message(msg)

      presence when elem(presence, 0) == :presence ->
        IO.inspect(packet, label: "Intercepted presence")

      _ ->
        IO.inspect(packet, label: "Intercepted packet")
    end

    packet
  end
end
