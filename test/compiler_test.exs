defmodule CompilerTest do
  use ExUnit.Case

  use TimeMachine

  import TestTemplates
  alias TimeMachine.Logic
  alias TimeMachine.Templates

  doctest TimeMachine.Compiler

  defp to_js(el) do
    TimeMachine.Compiler.to_ast(el)
    |> ESTree.Tools.Generator.generate(false)
  end

  defp call_tpl(name, assigns \\ []) when is_atom(name) do
    id = Logic.call_id(name, assigns)
    ast = apply(TestTemplates, name, [assigns])
    js = ast |> to_js()
    args = Templates.get_args(TestTemplates, id)
    call_js = %Logic.Call{mod: TestTemplates, id: id} |> to_js()
    %{id: id, js: js, ast: ast, args: args, call: call_js}
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

    assert quote(do: ~o(num) === 1234 and ~o(num2) === 1111)
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> to_js() == "num===1234&&num2===1111"

    assert_raise LogicError, fn ->
      quote(do: (if ~v(num) === ~o(num), do: div "yay"))
      |> Logic.clean_quoted()
      |> Logic.handle_logic()
      |> to_js()
    end
  end

  test "test templates render to js correctly" do
    # logic renders to js correctly
    tpl_logic_var = call_tpl(:tpl_logic_var)
    assert tpl_logic_var.js == "()=>[num==2?h('div','yay'):h('div','nope'),num==2?h('div','yay'):null,h('div',num!=2?'yay':'nope'),h('div',num!=2?'yay':null)]"

    tpl_logic_obv = call_tpl(:tpl_logic_obv)
    assert tpl_logic_obv.js == "({num})=>[t(num,num=>num==2?h('div','yay'):h('div','nope')),t(num,num=>num==2?h('div','yay'):null),h('div',t(num,num=>num!=2?'yay':'nope')),h('div',t(num,num=>num!=2?'yay':null))]"

    tpl_logic_multi_var = call_tpl(:tpl_logic_multi_var)
    assert tpl_logic_multi_var.js == "()=>[num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)]"

    tpl_logic_multi_obv = call_tpl(:tpl_logic_multi_obv)
    assert tpl_logic_multi_obv.js == "({num,mun})=>[c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))]"

    tpl_logic_multi_obv_var = call_tpl(:tpl_logic_multi_obv_var)
    assert tpl_logic_multi_obv_var.js == "({mun})=>[t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))]"

    tpl_logic_obv = call_tpl(:tpl_logic_obv)
    assert tpl_logic_obv.js == "({num})=>[t(num,num=>num==2?h('div','yay'):h('div','nope')),t(num,num=>num==2?h('div','yay'):null),h('div',t(num,num=>num!=2?'yay':'nope')),h('div',t(num,num=>num!=2?'yay':null))]"

    tpl_inner_tpl = call_tpl(:tpl_inner_tpl)
    assert tpl_inner_tpl.js == "()=>h('div',tpl_obv_18333003({num}),tpl_logic_mixed_53552546({oo}))"
  end

  test "basic panels generate proper js" do
    # TODO - keep track of scopes and then render templates into their outermost environment which satisfies their conditions (pure goes in the outermost)
    # TODO - store pure templates separate from the env templates (and call them from this universal location, passing the obv to the template)


    # TODO - estree optimisations:
    # - semicolons after return, break, continue, etc. statements.
    # - return [1,2,3]; -> return[1,2,3]

    # TODO: do this automatically enumerating TestTemplates.templates

    pnl_logic_var = call_tpl(:pnl_logic_var)
    pnl_logic_cdn = call_tpl(:pnl_logic_cdn)
    pnl_logic_obv = call_tpl(:pnl_logic_obv)
    pnl_logic_obv_var = call_tpl(:pnl_logic_obv_var)
    pnl_obv_assign = call_tpl(:pnl_obv_assign)


    # normal logic renders properly (they will assume that the obvs, `num` and `mun` already exist inside of its environment)
    assert pnl_logic_var.js == "({G,C})=>{const {h,t,c,v}=G,{mun,num}=C;return [num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)];}"
    assert pnl_logic_cdn.js == "({G,C})=>{const {h,t,c,v}=G,mun=v(C.mun),num=v(C.num);return [num==2&&mun==2?h('div','yay'):h('div','nope'),num==2&&mun==2?h('div','yay'):null,h('div',num!=2&&mun==2?'yay':'nope'),h('div',num!=2&&mun==2?'yay':null)];}"
    assert pnl_logic_obv.js == "({G,C})=>{const {h,t,c,v}=G,mun=v(),num=v();return [c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):h('div','nope')),c([mun,num],(mun,num)=>num==2&&mun==2?h('div','yay'):null),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':'nope')),h('div',c([mun,num],(mun,num)=>num!=2&&mun==2?'yay':null))];}"
    assert pnl_logic_obv_var.js == "({G,C})=>{const {h,t,c,v}=G,{num}=C,mun=v();return [t(mun,mun=>num==2&&mun==2?h('div','yay'):h('div','nope')),t(mun,mun=>num==2&&mun==2?h('div','yay'):null),h('div',t(mun,mun=>num!=2&&mun==2?'yay':'nope')),h('div',t(mun,mun=>num!=2&&mun==2?'yay':null))];}"

    # these test that defining an obv in the panel will defines its presence in that scope
    assert pnl_obv_assign.js == "({G,C})=>{const {h,t,c,v}=G,num=v(4);return h('div','num is',num);}"

    # this one doesn't work yet, because I need to save the templates by name and also assigns. then, inline the template into the env, and call the template
    # by default, it will consider all templates to be pure.
    # later, an optimisation pass will be able to remove passing of variables purely if purity isn't needed (thereby generating smaller code)

    tpl_logic_obv = call_tpl(:tpl_logic_obv)
    pnl_inner_obv_tpl = call_tpl(:pnl_inner_obv_tpl)

    assert tpl_logic_obv.js == "({num})=>[t(num,num=>num==2?h('div','yay'):h('div','nope')),t(num,num=>num==2?h('div','yay'):null),h('div',t(num,num=>num!=2?'yay':'nope')),h('div',t(num,num=>num!=2?'yay':null))]"
    assert pnl_inner_obv_tpl.js == "({G,C})=>{const {h,t,c,v}=G,num=v(4),#{tpl_logic_obv.id}=#{tpl_logic_obv.js};return h('div',#{tpl_logic_obv.id}({num}));}"

    tpl_inner_tpl = call_tpl(:tpl_inner_tpl)
    tpl_obv = call_tpl(:tpl_obv, [num: 1])
    tpl_logic_mixed = call_tpl(:tpl_logic_mixed, lala: 1234)
    pnl_inner_inner_tpl = call_tpl(:pnl_inner_inner_tpl)

    assert tpl_inner_tpl.js == "()=>h('div',tpl_obv_18333003({num}),tpl_logic_mixed_53552546({oo}))"
    assert tpl_logic_mixed.js == "({oo})=>[t(oo,oo=>oo==2?h('div','yay'):h('div','nope')),vv==2?h('div','yay'):h('div','nope'),h('div','nope'),t(oo,oo=>oo==2?h('div','yay'):null),vv==2?h('div','yay'):null,null,h('div',t(oo,oo=>oo!=2?'yay':'nope')),h('div',vv!=2?'yay':'nope'),h('div','yay'),h('div',t(oo,oo=>oo!=2?'yay':null)),h('div',vv!=2?'yay':null),h('div','yay')]"
    assert pnl_inner_inner_tpl.js == "({G,C})=>{const {h,t,c,v}=G,{vv}=C,num=v(4),oo=v(),#{tpl_inner_tpl.id}=#{tpl_inner_tpl.js},#{tpl_obv.id}=#{tpl_obv.js},#{tpl_logic_mixed.id}=#{tpl_logic_mixed.js};return h('div',#{tpl_inner_tpl.id}());}"
    assert tpl_obv.js == "({num})=>h('.tpl_obv','num is:',num,h('.click',h('button',{boink:m(num,num=>num+1)},'num++'),h('button',{boink:m(num,num=>num-1)},'num--')))"
  end

  test "templates cannot have assigns" do
    assert_raise LogicError, fn ->
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
    # this limitation can easily be relaxed. given:
    #  case x do y -> ... end
    # that can be transformed pretty easily into:
    #  cond do x == y -> ... end
    assert_raise LogicError, fn ->
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

  test "reserved names will produce errors" do
    # this one will go away when NameSpaceman is implemented.
    assert_raise LogicError, fn ->
      quote do
        template :reserved_name do
          div ~o(c)
        end
      end |> Logic.clean_quoted() |> Logic.handle_logic()
    end

    assert_raise LogicError, fn ->
      quote do
        template :reserved_name do
          div ~o(t)
        end
      end |> Logic.clean_quoted() |> Logic.handle_logic()
    end

    assert_raise LogicError, fn ->
      quote do
        template :reserved_name do
          div ~o(v)
        end
      end |> Logic.clean_quoted() |> Logic.handle_logic()
    end

    assert_raise LogicError, fn ->
      quote do
        template :reserved_name do
          div ~o(G)
        end
      end |> Logic.clean_quoted() |> Logic.handle_logic()
    end

    assert_raise LogicError, fn ->
      quote do
        template :reserved_name do
          div ~o(C)
        end
      end |> Logic.clean_quoted() |> Logic.handle_logic()
    end

    # assert_raise LogicError, fn ->
    #   quote do
    #     template :reserved_name do
    #       div ~o(m)
    #     end
    #   end |> Logic.clean_quoted() |> Logic.handle_logic()
    # end
  end

  test "cond statement cannot have guard clauses" do
    assert_raise LogicError, fn ->
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

  test "plugin demo works" do
    tpl_cdn = call_tpl(:tpl_cdn)
    tpl_obv = call_tpl(:tpl_obv)
    tpl_boink = call_tpl(:tpl_boink)
    tpl_words = call_tpl(:tpl_words)
    tpl_select = call_tpl(:tpl_select)
    pnl_plugin_demo = call_tpl(:pnl_plugin_demo)
    # ast = Templates.get_ast(TestTemplates, pnl_plugin_demo.id)
    # vars = Logic.enum_logic(ast, [:Obv, :Condition], :name, :count)
    # vars = Templates.get_vars(TestTemplates, pnl_plugin_demo.id)
    # calls = Templates.get_calls(TestTemplates, pnl_plugin_demo.id)
    # TODO: I need to make sure and for each call, also get those variables
    # IO.puts "vars: #{inspect vars}"
    # IO.puts "calls: #{inspect calls}"
    assert pnl_plugin_demo.js ==
      "({G,C})=>{" <>
        "const {h,t,c,v}=G," <>
          "lala=v(C.lala)," <>
          "sum=c([lala,num],(lala,num)=>num+lala)," <>
          "num=v(11)," <>
          "pressed=v(false)," <>
          "boinked=v(false)," <>
          "w2=v()," <>
          "w1=v()," <>
          "selected=v()," <>
          "#{tpl_cdn.id}=#{tpl_cdn.js}," <>
          "#{tpl_obv.id}=#{tpl_obv.js}," <>
          "#{tpl_boink.id}=#{tpl_boink.js}," <>
          "#{tpl_words.id}=#{tpl_words.js}," <>
          "#{tpl_select.id}=#{tpl_select.js}" <>
        ";return h('div'," <>
          "h('h1','simple plugin demo')," <>
          "h('hr')," <>
          "h('h3','conditions, numbers, and transformations')," <>
          "#{tpl_cdn.call}," <>
          "#{tpl_obv.call}," <>
          "h('hr')," <>
          "h('h3','mouse / touch events')," <>
          "#{tpl_boink.call}," <>
          "h('hr')," <>
          "h('h3','text input')," <>
          "#{tpl_words.call}," <>
          "h('hr')," <>
          "h('h3','select boxes')," <>
          "#{tpl_select.call}" <>
        ");" <>
      "}"
  end

  test "injected js renders proprly and plays nicely" do
    # TODO - ~j/var lala = 1234/ renders correctly
    # TODO - bonus: it'd be nice if it detected the existance of this environmental `Var`
  end
end
