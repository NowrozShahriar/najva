defmodule Najva.Ejabberd.ModNajva.Hooks do
  @moduledoc """
  Ejabberd hook handlers for filter_packet and offline_message_hook.
  """

  alias Najva.Chat

  @doc """
  Called by ejabberd for every single stanza.
  Hook: :filter_packet
  Callback signature: on_packet_intercept(Packet)
  """

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

  @doc """
  Called by ejabberd when user is offline and a message arrives.
  Hook: :offline_message_hook
  Callback signature: on_offline_message(Packet)
  """
  def on_offline_message(
        {:bounce, {:message, _id, _type, _lang, from, to, _subj, _body, _thread, [n], _meta}}
      ) do
    Chat.receive_message(from, to, n)
  end
end
