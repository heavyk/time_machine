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

  template :test_template do
    div "test #{@val}"
  end

  test "elements" do
    assert (div "one") == %E{tag: :div, content: "one"}
    assert (div [lala: 1234], "one") == %E{tag: :div, content: "one", attrs: [lala: 1234]}
  end

  test "templates" do
    assert (test_template([val: 1234])) == %E{tag: :div, content: "test 1234"}
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
  end
end
