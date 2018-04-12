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
    elements: TimeMachine.Elements,
    imports: []

  template :tpl_test do
    div "test #{@val}"
  end

  template :tpl_one_item_frag do
    fragment do
      div "test"
    end
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

  template :tpl_logic_obv do
    fragment do
      if ~o(num) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2, do: (div "yay")
      div if ~o(num) != 2, do: "yay", else: "nope"
      div if ~o(num) != 2, do: "yay"
    end
  end

  template :tpl_logic_var do
    fragment do
      if ~v(num) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2, do: (div "yay")
      div if ~v(num) != 2, do: "yay", else: "nope"
      div if ~v(num) != 2, do: "yay"
    end
  end

  template :tpl_logic_multi_var do
    fragment do
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv_var do
    fragment do
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv do
    fragment do
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_var do
    fragment do
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv_var do
    fragment do
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv do
    fragment do
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_mixed do
    fragment do
      if ~o(oo) == 2, do: (div "yay"), else: (div "nope")
      if ~v(vv) == 2, do: (div "yay"), else: (div "nope")
      if @num == 2, do: (div "yay"), else: (div "nope")
      if ~o(oo) == 2, do: (div "yay")
      if ~v(vv) == 2, do: (div "yay")
      if @num == 2, do: (div "yay")
      div if ~o(oo) != 2, do: "yay", else: "nope"
      div if ~v(vv) != 2, do: "yay", else: "nope"
      div if @num != 2, do: "yay", else: "nope"
      div if ~o(oo) != 2, do: "yay"
      div if ~v(vv) != 2, do: "yay"
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
  alias TimeMachine.Elements
  alias Marker.Element, as: E
  alias TimeMachine.Logic
  require Logic

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
                                         attrs: [ids: [], name: :tpl_test],
                                         content: %E{tag: :div,
                                                     content: "test 1234"}}
  end

  test "fragments" do
    assert tpl_one_item_frag() == %E{tag: :_template, content: %E{tag: :_fragment, content:
        %E{tag: :div, content: "test"}
      }, attrs: [ids: [], name: :tpl_one_item_frag]}

    assert (tpl_inner_frag([num: 11])) == %E{tag: :_template, content: %E{tag: :_fragment, content: [
        %E{tag: :div, content: 1},
        %E{tag: :div, content: 1.1},
        %E{tag: :div, content: 11},
        %E{tag: :div, content: 11.1}
      ]}, attrs: [ids: [], name: :tpl_inner_frag]}
  end

  test "components" do
    assert (foto size: 180, id: "lol", title: "an image") ==
      %E{tag: :_component, content: %E{tag: :img, attrs: [src: "/i/m/lol",
                                                          title: "an image",
                                                          alt: "an image"]},
         attrs: [ids: [], name: :foto]}
  end

  test "static logic" do
    assert tpl_logic_static([num: 1]) == %E{content:
      %E{content: [
        %E{content: "nope", tag: :div},
        nil,
        %E{content: "yay", tag: :div},
        %E{content: "yay", tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [ids: [], name: :tpl_logic_static]}

    assert tpl_logic_static([num: 2]) == %E{content:
      %E{content: [
        %E{content: "yay", tag: :div},
        %E{content: "yay", tag: :div},
        %E{content: "nope", tag: :div},
        %E{content: nil, tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [ids: [], name: :tpl_logic_static]}
  end

  test "obv/var logic" do
    assert Logic.clean(tpl_logic_obv()) == Logic.clean(%E{content:
      %E{content: [
        %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 2),
                              do: %E{content: "yay", tag: :div},
                            else: %E{content: "nope", tag: :div}},
        %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 2),
                              do: %E{content: "yay", tag: :div},
                            else: nil},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} != 2),
                                                    do: "yay",
                                                    else: "nope"},
                        tag: :div},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} != 2),
                                                    do: "yay",
                                                    else: nil},
                        tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [ids: [num: :Obv], name: :tpl_logic_obv]})

    assert Logic.clean(tpl_logic_var()) == Logic.clean(%E{content:
      %E{content: [
        %Logic.If{test: quote(do: %Logic.Var{name: "num"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: %E{content: "nope", tag: :div}},
        %Logic.If{test: quote(do: %Logic.Var{name: "num"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: nil},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Var{name: "num"} != 2),
                                                    do: "yay",
                                                    else: "nope"},
                        tag: :div},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Var{name: "num"} != 2),
                                                    do: "yay",
                                                    else: nil},
                        tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [ids: [num: :Var], name: :tpl_logic_var]})

    assert Logic.clean(tpl_logic_mixed([num: 2])) == Logic.clean(%E{content:
      %E{content: [
        %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: %E{content: "nope", tag: :div}},
        %Logic.If{test: quote(do: %Logic.Var{name: "vv"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: %E{content: "nope", tag: :div}},
        %E{content: "yay", tag: :div},

        %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: nil},
        %Logic.If{test: quote(do: %Logic.Var{name: "vv"} == 2),
                             do: %E{content: "yay", tag: :div},
                           else: nil},
        %E{content: "yay", tag: :div},

        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} != 2),
                                                    do: "yay",
                                                    else: "nope"},
                        tag: :div},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Var{name: "vv"} != 2),
                                                    do: "yay",
                                                    else: "nope"},
                        tag: :div},
        %E{content: "nope", tag: :div},

        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} != 2),
                                                    do: "yay",
                                                    else: nil},
                        tag: :div},
        %E{attrs: [],
                        content: %Logic.If{test: quote(do: %Logic.Var{name: "vv"} != 2),
                                                    do: "yay",
                                                    else: nil},
                        tag: :div},
        %E{content: nil, tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [ids: [vv: :Var, oo: :Obv], name: :tpl_logic_mixed]})
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
  alias TimeMachine.Elements
  alias TimeMachine.Logic

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

    # top-level template w/ variable interpolation
    assert (tpl_test([val: 1234])) |> to_js() ==
      "()=>h('div','test 1234')"

    # fragtments are always rendered as arrays (is this necessary?)
    assert tpl_one_item_frag() |> to_js() ==
      "()=>[h('div','test')]"

    # inner fragments
    assert (tpl_inner_frag([num: 11])) |> to_js() ==
      "()=>[h('div',1),h('div',1.1),h('div',11),h('div',11.1)]"

    assert (foto size: 180, id: "lol", title: "an image") |> to_js() ==
      "()=>h('img',{src:'/i/m/lol',title:'an image',alt:'an image'})"

    # merges duplicated attrs into an array
    assert (div [a: 1, a: 2, a: 3, a: 4]) |> to_js() == "h('div',{a:[1,2,3,4]})"

    # output the element as its css selector to save attribute space
    assert ~h/.c1.c2.c3#id/ |> to_js() == "h('.c1.c2.c3#id')"
    assert ~h/div.c1.c2.c3#id/ |> to_js() == "h('.c1.c2.c3#id')"
    assert ~h/custom-el.c1.c2.c3#id/ |> to_js() == "h('custom-el.c1.c2.c3#id')"

    # static logic renders to js correctly
    assert tpl_logic_static([num: 1]) |> to_js() == "()=>[h('div','nope'),null,h('div','yay'),h('div','yay')]"
    assert tpl_logic_static([num: 2]) |> to_js() == "()=>[h('div','yay'),h('div','yay'),h('div','nope'),h('div')]"

    # conditions are well met
    assert %Logic.Var{name: "num"}
      |> Logic.clean_quoted()
      |> to_js() == "num"
    assert quote(do: %Logic.Var{name: "num"} == 2)
      |> Logic.clean_quoted()
      |> to_js() == "num==2"
    assert quote(do: %Logic.Var{name: "num"} === %Logic.Var{name: "num2"})
      |> Logic.clean_quoted()
      |> to_js() == "num===num2"
    assert quote(do: ~o(num) === ~o(num2))
      |> Logic.clean_quoted()
      |> Elements.handle_logic()
      |> to_js() == "num===num2"
    assert quote(do: ~o(num) === "a string")
      |> Logic.clean_quoted()
      |> Elements.handle_logic()
      |> to_js() == "num==='a string'"
    assert quote(do: ~o(num) === 1234 && ~o(num2) === 1111)
      |> Logic.clean_quoted()
      |> Elements.handle_logic()
      |> to_js() == "num===1234&&num2===1111"
    assert_raise RuntimeError, fn ->
      quote(do: (if ~v(num) === ~o(num), do: div "yay"))
      |> Logic.clean_quoted()
      |> Elements.handle_logic()
      |> to_js()
    end

    # logic renders to js correctly
    assert tpl_logic_var() |> to_js() == "()=>[num==2?h('div','yay'):h('div','nope'),num==2?h('div','yay'):null,h('div',num!=2?'yay':'nope'),h('div',num!=2?'yay':null)]"
    assert tpl_logic_obv() |> to_js() == "({num})=>[t(num,num=>num==2?h('div','yay'):h('div','nope')),t(num,num=>num==2?h('div','yay'):null),h('div',t(num,num=>num!=2?'yay':'nope')),h('div',t(num,num=>num!=2?'yay':null))]"
    assert tpl_logic_multi_var() |> to_js() == "()=>[num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)]"
    assert tpl_logic_multi_obv() |> to_js() == "({num,mun})=>[c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))]"
    assert tpl_logic_multi_obv_var() |> to_js() == "({mun})=>[t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))]"

    # these are all going to change after I define better what a panel is.
    assert pnl_logic_var() |> to_js() == "()=>[num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)]"
    assert pnl_logic_obv() |> to_js() == "()=>[c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))]"
    assert pnl_logic_obv_var() |> to_js() == "()=>[t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))]"
  end


  defp to_js(el) do
    TimeMachine.Compiler.to_ast(el)
    |> ESTree.Tools.Generator.generate(false)
  end


end
