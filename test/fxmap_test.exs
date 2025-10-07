defmodule FxmapTest do
  use ExUnit.Case, async: true
  doctest Fxmap

  # The original XML of the test case
  # <root>
  #   <parent attr1="value1">
  #     <child1 a="v" b="v2" c="v3">
  #       <nested>deeply nested cdata</nested>
  #       <nested id="s2"/>
  #     </child1>
  #   </parent>
  #
  #   <parent>
  #     <mixed_content type="data">
  #       cdata1
  #       <sub_element/>
  #       cdata2
  #     </mixed_content>
  #   </parent>
  #
  #   <text_only>plain text content</text_only>
  #
  #   <empty_tag/>
  #   <empty_with_attr flag="true"/>
  # </root>

  @sample_xml_tuple {:xmlel, "root", [],
                     [
                       {:xmlel, "parent", [{"attr1", "value1"}],
                        [
                          {:xmlel, "child1", [{"a", "v"}, {"b", "v2"}, {"c", "v3"}],
                           [
                             {:xmlel, "nested", [], [xmlcdata: "deeply nested cdata"]},
                             {:xmlel, "nested", [{"id", "s2"}], []}
                           ]}
                        ]},
                       {:xmlel, "parent", [],
                        [
                          {:xmlel, "mixed_content", [{"type", "data"}],
                           [
                             {:xmlcdata, "cdata1"},
                             {:xmlel, "sub_element", [], []},
                             {:xmlcdata, "cdata2"}
                           ]}
                        ]},
                       {:xmlel, "text_only", [], [xmlcdata: "plain text content"]},
                       {:xmlel, "empty_tag", [], []},
                       {:xmlel, "empty_with_attr", [{"flag", "true"}], []}
                     ]}

  describe "decode/1" do
    test "correctly decodes complex XML tuples into a map with atom keys" do
      expected_map = %{
        root: %{
          parent: [
            %{
              mixed_content: %{
                _@cdata: ["cdata2", "cdata1"],
                _@attrs: %{type: "data"},
                sub_element: :sub_element
              }
            },
            %{
              _@attrs: %{attr1: "value1"},
              child1: %{
                _@attrs: %{c: "v3", a: "v", b: "v2"},
                nested: [%{_@attrs: %{id: "s2"}}, %{_@cdata: "deeply nested cdata"}]
              }
            }
          ],
          text_only: %{_@cdata: "plain text content"},
          empty_tag: :empty_tag,
          empty_with_attr: %{_@attrs: %{flag: "true"}}
        }
      }

      assert Fxmap.decode(@sample_xml_tuple) == expected_map
    end
  end

  describe "decode_raw/1" do
    test "correctly decodes complex XML tuples into a map with string keys" do
      expected_map = %{
        "root" => %{
          "empty_tag" => "empty_tag",
          "empty_with_attr" => %{"_@attrs" => %{"flag" => "true"}},
          "parent" => [
            %{
              "mixed_content" => %{
                "_@attrs" => %{"type" => "data"},
                "_@cdata" => ["cdata2", "cdata1"],
                "sub_element" => "sub_element"
              }
            },
            %{
              "_@attrs" => %{"attr1" => "value1"},
              "child1" => %{
                "_@attrs" => %{"a" => "v", "b" => "v2", "c" => "v3"},
                "nested" => [
                  %{"_@attrs" => %{"id" => "s2"}},
                  %{"_@cdata" => "deeply nested cdata"}
                ]
              }
            }
          ],
          "text_only" => %{"_@cdata" => "plain text content"}
        }
      }

      assert Fxmap.decode_raw(@sample_xml_tuple) == expected_map
    end
  end
end
