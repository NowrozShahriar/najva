defmodule Najva.Fxmap do
  @moduledoc """
  A utility for converting Erlang XML tuples, like those from `:fast_xml`, into Elixir maps.

  This module provides two main functions for decoding:

  * `decode/1` - Decodes into a map with string keys, flattening attributes with an `@` prefix. This is useful for simpler, more direct access in Elixir code.
  * `decode_raw/1` - Decodes into a map with string keys, preserving all original names and grouping attributes under an `@attrs` key.

  The structure of the resulting map aims to be intuitive:
  - XML elements become keys in the map.
  - Attributes are prefixed with `@` in `decode/1`, or grouped under an `@attrs` key in `decode_raw/1`.
  - Character data (cdata) is placed under an `@cdata` key.
  - If multiple elements share the same name at the same level, they are collected into a list.
  """

  # --- Simple Mode ---
  # -------------------

  @doc """
  Decodes an Erlang XML tuple into a map with string keys.

  This function recursively transforms :xmlel tuples into a nested map.
  Attributes are flattened into the map and prefixed with `@` to distinguish
  them from child elements.


  ## Example

      iex> xml = {:xmlel, "message", [{"to", "user@example.com"}], [{:xmlel, "body", [], [{:xmlcdata, "Hello"}]}]}
      iex> Najva.Fxmap.decode(xml)
      %{
        "message" => %{
          "@to" => "user@example.com",
          "body" => %{"@cdata" => "Hello"}
        }
      }
  """
  def decode(xml_tuple), do: Map.new([decode_s(xml_tuple)])

  defp decode_s({:xmlel, name, [], []}), do: {name, name}

  defp decode_s({:xmlel, name, attrs, children}),
    do: {
      name,
      Map.new(attrs, fn {k, v} -> {"@" <> k, v} end)
      |> handle_children(children, &decode_s/1)
    }

  defp decode_s({:xmlcdata, content}), do: {"@cdata", content}
  defp decode_s({:xmlstreamelement, element}), do: decode_s(element)

  defp decode_s({:xmlstreamstart, name, attrs}),
    do: {name, Map.new(attrs, fn {k, v} -> {"@" <> k, v} end)}

  defp decode_s(_), do: {:error, :unknown_format}

  # --- Verbose Mode ---
  # --------------------
  @doc """
  Decodes an Erlang XML tuple into a map with string keys.

  This function provides a literal translation from the :xmlel tuple structure
  to a map. Attributes are grouped under the `@attrs` key.

  ## Example

      iex> xml = {:xmlel, "ns:message", [{"to", "user@example.com"}], [{:xmlel, "body", [], [{:xmlcdata, "Hello"}]}]}
      iex> Najva.Fxmap.decode_raw(xml)
      %{
        "ns:message" => %{
          "@attrs" => %{"to" => "user@example.com"},
          "body" => %{"@cdata" => "Hello"}
        }
      }

  """
  def decode_raw(xml_tuple), do: Map.new([decode_r(xml_tuple)])

  defp decode_r({:xmlel, name, [], []}), do: {name, name}

  defp decode_r({:xmlel, name, attrs, children}),
    do: {
      name,
      unless attrs == [] do
        Map.put(%{}, "@attrs", Map.new(attrs))
      else
        %{}
      end
      |> handle_children(children, &decode_r/1)
    }

  defp decode_r({:xmlcdata, content}), do: {"@cdata", content}
  defp decode_r({:xmlstreamelement, element}), do: decode_r(element)
  defp decode_r({:xmlstreamstart, name, attrs}), do: {name, %{"@attrs" => Map.new(attrs)}}
  defp decode_r(_), do: {:error, :unknown_format}

  # --- Helpers ---
  # ---------------
  defp handle_children(map, [], _), do: map

  defp handle_children(map, children, fun) do
    children
    |> Enum.map(fun)
    |> Enum.reduce(map, fn {key, value}, map ->
      # in Map.update the callback fn is only called when the key already exists
      Map.update(map, key, value, fn existing_value ->
        if is_list(existing_value) do
          [value | existing_value]
        else
          [value, existing_value]
        end
      end)
    end)
  end

  #   defp atomize(key) do
  #     # case :binary.split(key, ":") do
  #     #   [local] -> String.to_atom(local)
  #     #   [_prefix, local] -> atomize(local)
  #     # end
  #     String.to_atom(key)
  #   end
  #
  #   defp handle_attrs([]), do: %{}
  #
  #   defp handle_attrs(attrs) do
  #     # Map.put(
  #     #   %{},
  #     #   :attrs!,
  #     Map.new(attrs, fn {k, v} -> {atomize("@" <> k), v} end)
  #     # )
  #   end
end
