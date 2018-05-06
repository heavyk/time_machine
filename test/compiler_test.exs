defmodule CompilerTest do
  use ExUnit.Case

  use TimeMachine

  import TestTemplates
  alias TimeMachine.Logic

  doctest TimeMachine.Compiler

  defp to_js(el) do
    TimeMachine.Compiler.to_ast(el)
    |> ESTree.Tools.Generator.generate(false)
  end

  test "elements generate proper js" do
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
  end

  test "logic generates proper js" do
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
      |> Logic.handle_logic()
      |> to_js() == "num===num2"
    assert quote(do: ~o(num) === "a string")
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> to_js() == "num==='a string'"
    assert quote(do: ~o(num) === 1234 && ~o(num2) === 1111)
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> to_js() == "num===1234&&num2===1111"
    assert_raise RuntimeError, fn ->
      quote(do: (if ~v(num) === ~o(num), do: div "yay"))
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> to_js()
    end

    # logic renders to js correctly
    assert tpl_logic_var() |> to_js() == "()=>[num==2?h('div','yay'):h('div','nope'),num==2?h('div','yay'):null,h('div',num!=2?'yay':'nope'),h('div',num!=2?'yay':null)]"
    assert tpl_logic_obv() |> to_js() == "({num})=>[t(num,num=>num==2?h('div','yay'):h('div','nope')),t(num,num=>num==2?h('div','yay'):null),h('div',t(num,num=>num!=2?'yay':'nope')),h('div',t(num,num=>num!=2?'yay':null))]"
    assert tpl_logic_multi_var() |> to_js() == "()=>[num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)]"
    assert tpl_logic_multi_obv() |> to_js() == "({num,mun})=>[c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))]"
    assert tpl_logic_multi_obv_var() |> to_js() == "({mun})=>[t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))]"
  end

  test "basic panels generate proper js" do
    # TODO - keep track of scopes and then render templates into their outermost environment which satisfies their conditions (pure goes in the outermost)
    # TODO - store pure templates separate from the env templates (and call them from this universal location, passing the obv to the template)


    # TODO - estree optimisations:
    # - semicolons after return, break, continue, etc. statements.
    # - return [1,2,3]; -> return[1,2,3]


    # normal logic renders properly (they will assume that the obvs, `num` and `mun` already exist inside of its environment)
    assert pnl_logic_var() |> to_js() == "({G,C})=>{const {h,t,c,v}=G;return [num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)];}"
    assert pnl_logic_obv() |> to_js() == "({G,C})=>{const {h,t,c,v}=G;return [c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))];}"
    assert pnl_logic_obv_var() |> to_js() == "({G,C})=>{const {h,t,c,v}=G;return [t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))];}"

    # these test that defining an obv in the panel will defines its presence in that scope
    assert pnl_obv_assign() |> to_js() == "({G,C})=>{const {h,t,c,v}=G,num=v(4);return h('div','num is',num);}"

    # this one doesn't work yet, because I need to save the templates by name and also assigns. then, inline the template into the env, and call the template
    # it may be helpful to start with elements_test and generate Logic.Call{name: :tpl_logic_obv, params: [{:num}]} structs.
    tpl_logic_obv_js = tpl_logic_obv() |> to_js()
    assert pnl_inner_tpl() |> to_js() == "({G,C})=>{const {h,t,c,v}=G,num=v(4),tpl_logic_obv=#{tpl_logic_obv_js};return h('div',tpl_logic_obv({num}));}"
  end

  test "templates cannot have assigns" do
    assert_raise TemplateCompileError, fn ->
      quote do
        template :no_tpl_assigns do
          ~o(yum) = 11
          div "badness"
        end
      end
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
    end
  end

  test "case statement is not yet supported" do
    assert_raise RuntimeError, fn ->
      quote do
        template :no_case_statement do
          case ~o(yum) do
            11 -> div "not gonna work"
            _ -> div "neither this"
          end
        end
      end
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
    end
  end

  test "cond statement cannot have guard clauses" do
    assert_raise RuntimeError, fn ->
      quote do
        template :no_guard_clauses do
          cond do
            ~o(lala) when is_nil(~o(lala)) -> div "not gonna work"
            ~o(lala) == 11 when is_integer(~o(lala)) -> div "not gonna work"
            true -> div "nope"
          end
        end
      end
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> IO.inspect
    end
  end

  test "injected js renders proprly and plays nicely" do
    # TODO - ~j/var lala = 1234/ renders correctly
    # TODO - bonus: it'd be nice if it detected the existance of this environmental `Var`
  end
end
