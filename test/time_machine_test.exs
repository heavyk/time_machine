defmodule TimeMachineTest do
  use ExUnit.Case
  doctest TimeMachine

  test "greets the world" do
    assert TimeMachine.hello() == :world
  end
end

defmodule TestTemplates do
  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements

  template :tpl_test do
    div "test #{@val}"
  end

  fragment :frag_test do
    div 1
    div 1.1
    div @num
    div @num + 0.1
  end

  template :tpl_inner_frag do
    num = 1
    fragment do
      div num
      div num + 0.1
      div @num
      div @num + 0.1
    end
  end

  template :tpl_logic_static do
    fragment do
      if @num == 2, do: (div "yay"), else: (div "nope")
      if @num == 2, do: (div "yay")
      div if @num != 2, do: "yay", else: "nope"
      div if @num != 2, do: "yay"
    end
  end

  component :foto do
    size = @size
    size = cond do
      size <= 150 -> :s
      size <= 300 -> :m
      size <= 600 -> :l
      size <= 1200 -> :x
    end
    src = "/i/#{size}/#{@id}"
    img src: src, title: @title, alt: @title
  end
end

# this will be moved out to its own project as soon as it's all working
defmodule ElementsTest do
  use ExUnit.Case
  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements

  import TestTemplates
  alias Marker.Element, as: E

  doctest TimeMachine.Elements

  test "elements" do
    assert (div "one") == %E{tag: :div, content: "one"}
    assert (div [lala: 1234], "one") == %E{tag: :div, content: "one", attrs: [lala: 1234]}
    assert (div [a: 1, a: 2, a: 3, a: 4]) == %E{tag: :div, attrs: [a: 1, a: 2, a: 3, a: 4]}

    # test selectors instead of a kw-list
    assert (div 'lala.c1') == %E{tag: :div, attrs: [class: :c1]}
    assert (div '.c1') == %E{tag: :div, attrs: [class: :c1]}
    assert (div '.c1.c2.c3') == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3]}
    assert (div '.c1.c2.c3#id') == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3, id: :id]}
    assert (div '#id', do: "lala") == %E{tag: :div, attrs: [id: :id], content: "lala"}

    # ensure binaries are never parsed as selectors
    assert (div "...") == %E{tag: :div, content: "..."}
    assert (div "#1") == %E{tag: :div, content: "#1"}

    assert ~h/div.c1/ == %E{tag: :div, attrs: [class: :c1]}
    assert ~h/.c1/ == %E{tag: :div, attrs: [class: :c1]}
    assert ~h/.c1.c2.c3/ == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3]}
    assert ~h/.c1.c2.c3#id/ == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3, id: :id]}
  end

  test "templates" do
    assert (tpl_test([val: 1234])) == %E{tag: :_template,
                                         content: %E{tag: :div,
                                                     content: "test 1234"}}
  end

  test "fragments" do
    assert (frag_test([num: 11])) == %E{tag: :_fragment, content: [
        %E{tag: :div, content: 1},
        %E{tag: :div, content: 1.1},
        %E{tag: :div, content: 11},
        %E{tag: :div, content: 11.1}
      ]}

    assert (tpl_inner_frag([num: 11])) == %E{tag: :_template, content: %E{tag: :_fragment, content: [
        %E{tag: :div, content: 1},
        %E{tag: :div, content: 1.1},
        %E{tag: :div, content: 11},
        %E{tag: :div, content: 11.1}
      ]}}
  end

  test "components" do
    assert (foto size: 180, id: "lol", title: "an image") ==
      %E{tag: :_component, content: %E{tag: :img, attrs: [src: "/i/m/lol",
                                                          title: "an image",
                                                          alt: "an image"]}}
  end

  test "static logic" do
    assert tpl_logic_static([num: 1]) == %Marker.Element{attrs: [], content:
      %Marker.Element{attrs: [], content: [
        %Marker.Element{attrs: [], content: "nope", tag: :div},
        nil,
        %Marker.Element{attrs: [], content: "yay", tag: :div},
        %Marker.Element{attrs: [], content: "yay", tag: :div}
      ], tag: :_fragment
    }, tag: :_template}

    assert tpl_logic_static([num: 2]) == %Marker.Element{attrs: [], content:
      %Marker.Element{attrs: [], content: [
        %Marker.Element{attrs: [], content: "yay", tag: :div},
        %Marker.Element{attrs: [], content: "yay", tag: :div},
        %Marker.Element{attrs: [], content: "nope", tag: :div},
        %Marker.Element{attrs: [], content: nil, tag: :div}
      ], tag: :_fragment
    }, tag: :_template}
  end
end

# defmodule CompilerTest.JsCompiler do
#   def compile(content) do
#     js = TimeMachine.Compiler.to_ast(content)
#     |> ESTree.Tools.Generator.generate(false)
#     {:safe, js}
#   end
# end

defmodule CompilerTest do
  use ExUnit.Case
  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements

  import TestTemplates

  defp to_js(el), do: TimeMachine.Compiler.to_ast(el) |> ESTree.Tools.Generator.generate(false)

  doctest TimeMachine.Compiler

  test "generate js" do
    assert (div "one") |> to_js() ==
        "h('div','one')"

    assert (div [lala: 1234, wewe: "lol"], "one") |> to_js() ==
        "h('div',{lala:1234,wewe:'lol'},'one')"

    assert (div do
      div [lala: 1234, wewe: "lol"], "one"
      div "two"
    end) |> to_js() == "h('div',h('div',{lala:1234,wewe:'lol'},'one'),h('div','two'))"

    # top-level template/fragment w/ variable interpolation
    assert (tpl_test([val: 1234])) |> to_js() ==
      "()=>h('div','test 1234')"
    assert (frag_test([num: 11])) |> to_js() ==
      "()=>[h('div',1),h('div',1.1),h('div',11),h('div',11.1)]"

    # inner fragments
    # TODO: although, the double functions is correct, one of them should be removed
    assert (tpl_inner_frag([num: 11])) |> to_js() ==
      "()=>()=>[h('div',1),h('div',1.1),h('div',11),h('div',11.1)]"

    assert (foto size: 180, id: "lol", title: "an image") |> to_js() ==
      "()=>h('img',{src:'/i/m/lol',title:'an image',alt:'an image'})"

    # merges duplicated attrs into an array
    assert (div [a: 1, a: 2, a: 3, a: 4]) |> to_js() == "h('div',{a:[1,2,3,4]})"

    # output the element as its css selector to save attribute space
    assert ~h/.c1.c2.c3#id/ |> to_js() == "h('.c1.c2.c3#id')"
    assert ~h/div.c1.c2.c3#id/ |> to_js() == "h('.c1.c2.c3#id')"
    assert ~h/custom-el.c1.c2.c3#id/ |> to_js() == "h('custom-el.c1.c2.c3#id')"
  end
end
