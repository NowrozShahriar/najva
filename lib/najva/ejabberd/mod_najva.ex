defmodule Najva.Ejabberd.ModNajva do
  @moduledoc """
  This module is an extension for ejabberd server to handle custom Najva packets.
  """
  @behaviour :gen_mod

  # 1. This runs when ejabberd starts the module
  def start(host, _opts) do
    # -- PATH A: The IQ Handler --
    # Tell ejabberd: "If you see an IQ with xmlns='najva:iq', send it to :handle_iq"
    :gen_iq_handler.add_iq_handler(
      :ejabberd_local,
      host,
      "najva:iq",
      Najva.Ejabberd.ModNajva.IqHandler,
      :handle_iq
    )

    # -- PATH B: The Packet Hook --
    # Tell ejabberd: "Every time a packet is routed, let me look at it first"
    # 50 is the priority (execution order if there are multiple hooks)
    :ejabberd_hooks.add(
      :filter_packet,
      :global,
      Najva.Ejabberd.ModNajva.Interceptor,
      :on_packet_intercept,
      50
    )

    :ok
  end

  # 2. This runs when ejabberd shuts down the module
  def stop(host) do
    :gen_iq_handler.remove_iq_handler(:ejabberd_local, host, "najva:iq")

    :ejabberd_hooks.delete(
      :filter_packet,
      :global,
      Najva.Ejabberd.ModNajva.Interceptor,
      :on_packet_intercept,
      50
    )

    :ok
  end

  def reload(host, new_opts, _old_opts) do
    stop(host)
    start(host, new_opts)
    :ok
  end

  # --- Required boilerplate for modern ejabberd modules ---
  def depends(_, _), do: []
  def mod_options(_), do: []
  def mod_doc(), do: %{desc: "This module handles custom Najva packets and IQ handlers."}
end
