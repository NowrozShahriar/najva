defmodule Fxmap do
  @moduledoc """
  A utility for converting Erlang XML tuples, like those from `:fast_xml`, into Elixir maps.

  This module provides two main functions for decoding:

  * `decode/1` - Decodes into a map with atom keys, stripping XML namespaces from element and attribute names. This is useful for simpler, more direct access in Elixir code.
  * `decode_raw/1` - Decodes into a map with string keys, preserving all original names and structures.

  The structure of the resulting map aims to be intuitive:
  - XML elements become keys in the map.
  - Attributes are grouped under an `_@attrs` key.
  - Character data (cdata) is placed under an `_@cdata` key.
  - If multiple elements share the same name at the same level, they are collected into a list.
  """

  # --- Simple Mode ---
  # -------------------

  @doc """
  Decodes an Erlang XML tuple into a map with atom keys.

  This function recursively transforms the XML structure into a nested map.
  It converts element and attribute names to atoms and strips any XML namespace
  prefixes (e.g., "prefix:name" becomes `:name`).

  ## Performance

  This function is approximately 4x slower than `decode_raw/1` due to the
  runtime conversion of strings to atoms. It is recommended to use `decode/1`
  primarily for development and testing. For production environments,
  `decode_raw/1` is the recommended choice for better performance.

  ## Example

      iex> xml = {:xmlel, "message", [{"to", "user@example.com"}], [{:xmlel, "body", [], [{:xmlcdata, "Hello"}]}]}
      iex> Fxmap.decode(xml)
      %{
        message: %{
          _@attrs: %{to: "user@example.com"},
          body: %{_@cdata: "Hello"}
        }
      }
  """
  def decode(xml_tuple), do: Map.new([decode_s(xml_tuple)])

  defp decode_s({:xmlel, name, [], []}), do: atomize(name) |> then(&{&1, &1})

  defp decode_s({:xmlel, name, attrs, children}),
    do: {
      atomize(name),
      handle_attrs(attrs)
      |> handle_children(children, &decode_s/1)
    }

  defp decode_s({:xmlcdata, content}), do: {:_@cdata, content}
  defp decode_s({:xmlstreamelement, element}), do: decode_s(element)
  defp decode_s({:xmlstreamstart, name, attrs}), do: {atomize(name), handle_attrs(attrs)}
  defp decode_s(_), do: {:error, :unknown_format}

  # --- Verbose Mode ---
  # --------------------
  @doc """
  Decodes an Erlang XML tuple into a map with string keys, preserving original names.

  This function provides a more literal translation from the XML tuple structure
  to a map. All element and attribute names are kept as strings, including any
  namespace prefixes.

  ## Example

      iex> xml = {:xmlel, "ns:message", [{"to", "user@example.com"}], [{:xmlel, "body", [], [{:xmlcdata, "Hello"}]}]}
      iex> Fxmap.decode_raw(xml)
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
  defp atomize(key) do
    case :binary.split(key, ":") do
      [local] -> String.to_atom(local)
      [_prefix, local] -> atomize(local)
    end
  end

  defp handle_attrs([]), do: %{}

  defp handle_attrs(attrs) do
    Map.put(
      %{},
      :_@attrs,
      Map.new(attrs, fn {k, v} -> {atomize(k), v} end)
    )
  end

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
end
