defmodule TimeMachineTest do
  use ExUnit.Case
  doctest TimeMachine

  test "greets the world" do
    assert TimeMachine.hello() == :world
  end
end

# this will be moved out to its own project as soon as it's all working
defmodule CompilerTest do
  use ExUnit.Case
  doctest TimeMachine.Compiler

  defp to_js(el), do: TimeMachine.Compiler.to_ast(el) |> ESTree.Tools.Generator.generate(false)

  alias Marker.Element, as: E
  use Marker,
    compiler: TimeMachine.Compiler,
    elements: Elements
  import Elements

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

  test "elements" do
    assert (div "one") == %E{tag: :div, content: "one"}
    assert (div [lala: 1234], "one") == %E{tag: :div, content: "one", attrs: [lala: 1234]}
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
  end

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

  end
end
