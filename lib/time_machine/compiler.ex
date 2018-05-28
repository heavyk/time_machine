defmodule TimeMachine.Compiler do
  alias Marker.Element
  alias TimeMachine.Logic
  alias TimeMachine.Templates
  alias ESTree.Tools.Builder, as: J
  alias ESTree.Tools.Generator

  defdelegate generate(ast), to: Generator

  defguard is_literal(v) when is_binary(v) or is_number(v) or is_atom(v) or is_boolean(v) or is_nil(v)

  def compile(content) when is_list(content) do
    Enum.map(content, &compile/1)
  end
  def compile(%Element{tag: tag, attrs: attrs, content: content}) do
    attrs = Enum.map(attrs, fn {k, v} ->
      case k do
        evt when evt in [:boink, :press] ->
          evt = case evt do
            :boink -> Logic.Modify
            :press -> Logic.Press
          end
          {k, Macro.prewalk(v, fn
            { sigil, _meta, [{:<<>>, _, [name]}, _]} when sigil in [:sigil_O, :sigil_o] ->
              type = case sigil do
                :sigil_O -> Logic.Condition
                :sigil_o -> Logic.Obv
              end

              quote do: %unquote(evt){obv: %unquote(type){name: unquote(name)}}

            {:<-, _, [lhs, rhs]} ->
              {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, _type] = mod}, {:%{}, _, [name: name]}]} = Logic.clean_quoted(lhs)
              fun = Logic.clean_quoted(rhs) |> Macro.escape()
              type = Module.concat(mod)
              quote do: %unquote(evt){obv: %unquote(type){name: unquote(name)}, fun: unquote(fun)}

            expr -> expr
          end)}

        _ -> {k, v}
      end
    end)
    content = cond do
      is_list(content) ->
        case length(content) do
          0 -> nil
          1 -> hd(content)
          _ -> content
        end
      true -> content
    end
    quote do: %Element{tag: unquote(tag), attrs: unquote(attrs), content: unquote(content)}
  end
  def compile(value) do
    TimeMachine.Encoder.encode(value)
  end

  # opuerator layout
  # @unary_operator       [ :-, :+, :!, :"~", :typeof, :void, :delete ]
  @unary_operator       [ :typeof, :void, :delete ]

  @binary_operator      [ :==, :!=, :===, :!==, :<, :<=, :>, :>=,
                          :"<<", :">>", :>>>, :+, :-, :*, :/, :%, :|,
                          :^, :&, :in, :instanceof, :"**" ]

  @logical_operator     [ :&&, :||, :and, :or ]

  @assignment_operator  [ :=, :"+=", :"-=", :"*=", :"/=", :"%=",
                          :"<<=", :">>=", :">>>=",
                          :"|=", :"^=", :"&=", :"**=" ]

  # @update_operator      [ :++, :-- ]
  # not really supported by the elixir compiler.
  # should really only be used for optimisations

  # @operator @unary_operator ++ @binary_operator ++ @logical_operator ++ @assignment_operator ++ @update_operator

  # convert to javascript

  def to_js(ast) do
    generate(ast)
  end

  # convert to ast

  def to_ast(content) when is_list(content) do
    Enum.map(content, &to_ast/1) |> J.array_expression()
  end
  def to_ast(value) when is_atom(value) and value != nil and value != false do
    J.identifier(value)
  end
  def to_ast(value) when is_literal(value) do
    J.literal(value)
  end
  def to_ast({:%, [], [aliases_, {:%{}, _, map_}]}) do
    {:__aliases__, [alias: mod_a], mod} = aliases_
    mod = cond do
      mod_a == false and is_list(mod) -> Module.concat(mod)
      mod_a != false and is_atom(mod_a) -> mod_a
    end
    struct(mod, map_)
    |> to_ast()
  end
  def to_ast({op, _meta, [lhs, rhs]}) when op in @logical_operator do
    op = case op do
      :and -> :&&
      :or  -> :||
      _    -> op
    end
    J.logical_expression(op, to_ast(lhs), to_ast(rhs))
  end
  def to_ast({op, _meta, [lhs, rhs]}) when op in @binary_operator do
    J.binary_expression(op, to_ast(lhs), to_ast(rhs))
  end
  def to_ast({op, _meta, [lhs, rhs]}) when op in @assignment_operator do
    J.assignment_expression(op, to_ast(lhs), to_ast(rhs))
  end
  def to_ast({op, _meta, [expr]}) when op in @unary_operator do
    J.unary_expression(op, true, to_ast(expr))
  end
  def to_ast(%Logic.Js{content: content}) do
    content = txt_to_ast(content) # TODO: for reals, convert to ast and then do do variable name transformations as well
    {:safe, content}
  end
  def to_ast(%Logic.Var{name: name}) do
    # NameSpaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Obv{name: name}) do
    # NameSpaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Condition{name: name}) do
    # NameSpaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Ref{name: name}) do
    J.member_expression(id(:G), to_ast(name), true)
  end
  def to_ast(%Logic.Call{mod: mod, id: id_, name: name, assigns: assigns}) do
    case function_exported?(mod, name, length(assigns)) do
      true -> apply(mod, name, assigns)
      _ -> nil
    end
    args = Templates.get_args(mod, id_)
    args = case length(args) do
      0 -> []
      _ -> [J.object_pattern(Enum.map(args, fn {k, _v} -> id(k) end))]
    end
    J.call_expression(id(id_), args)
  end
  def to_ast(%Logic.Modify{obv: obv, fun: fun}) do
    %_type{name: name} = obv
    fun = Macro.expand(fun, __ENV__)
    fun = J.arrow_function_expression([id(name)], [], to_ast(fun))
    J.call_expression(id(:m), [id(name), fun])
  end
  def to_ast(%Logic.Transform{obv: obv, fun: fun}) do
    fun = Macro.expand(fun, __ENV__)
    case is_list(obv) do
      true ->
        args = Enum.map(List.wrap(obv), fn obv ->
          %{name: name} = obv
          id(name)
        end)
        fun = J.arrow_function_expression(args, [], to_ast(fun))
        J.call_expression(id(:c), [J.array_expression(args), fun])
      _ ->
        %_type{name: name} = obv
        fun = J.arrow_function_expression([id(name)], [], to_ast(fun))
        J.call_expression(id(:t), [id(name), fun])
    end
  end

  def to_ast(%Logic.If{tag: :_if, test: test_, do: do_, else: else_}) do
    obvs = Logic.enum_logic(test_, [:Obv, :Ref])
    stmt = J.conditional_statement(to_ast(test_), to_ast(else_), to_ast(do_))
    case length(obvs) do
      0 -> stmt
      1 ->
        {k, _v} = hd(obvs)
        fun = J.arrow_function_expression([id(k)], [], stmt)
        J.call_expression(id(:t), [id(k), fun])
      _ ->
        keys = id(obvs)
        fun = J.arrow_function_expression(keys, [], stmt)
        J.call_expression(id(:c), [J.array_expression(keys), fun])
    end
  end
  def to_ast(%Element{tag: :_fragment, content: content}) do
    # for now, we're outputting an array by default, but I imagine that the obv replcement code
    # could replace individual elements, fragments, and null elements just fine. so, maybe we
    # can remove the List.wrap then
    to_ast(List.wrap(content))
  end
  def to_ast(%Element{tag: :_template, content: content, attrs: attrs}) do
    obvs = Enum.reduce(attrs[:ids], [], fn {k, v}, acc ->
      case v do
        :Obv -> [id(k) | acc]
        _ -> acc
      end
    end)
    args = cond do
      length(obvs) > 0 -> [J.object_pattern(obvs)]
      true -> []
    end
    J.arrow_function_expression(args, [], to_ast(content))
  end
  def to_ast(%Element{tag: :_component, content: content}) do
    J.arrow_function_expression([], [], to_ast(content))
  end
  def to_ast(%Element{tag: :_panel, content: ast, attrs: info}) do
    lib = Logic.lib_fns() # OPTIMISE: for now, we define all of them, but in the future, only defnine the ones that are required
    mod = Keyword.get(info, :module)
    calls =
      Logic.enum_logic(ast, :Call, :id, :count)
      |> Enum.reduce([], fn {id, count}, calls ->
        Templates.get_calls(mod, id)
        |> Keyword.merge(calls)
        |> Keyword.merge([{id, count}])
      end)
    vars =
      Templates.ast_vars(mod, ast)
      |> Enum.group_by(fn {_, type} -> type end, fn {name, _} -> name end)

    %{:Var => vars, :Condition => cdns, :Obv => obvs} =
      Map.merge(%{:Var => [], :Condition => [], :Obv => []}, vars)

    lib_decl = [J.variable_declarator(J.object_pattern(id(lib)), id(:G))]
    var_decl = case length(vars) do
      0 -> []
      _ -> [J.variable_declarator(J.object_pattern(id(vars)), id(:C))]
    end
    cdn_decl = case length(cdns) do
      0 -> []
      _ ->
      Enum.map(cdns, fn k ->
        cvar = J.member_expression(id(:C), id(k), compute_id?(k))
        cvar = J.call_expression(id(:v), [cvar])
        J.variable_declarator(id(k), cvar)
      end)
    end
    obv_init = Keyword.get(info, :init, [])
    obv_decl = case length(obvs) do
      0 -> []
      _ -> Enum.map(obvs, fn k ->
        init = Keyword.get(obv_init, k)
        type = Logic.type_of(init)
        init = cond do
          type in [:Transform] -> to_ast(init)
          type in [:Var] ->
            %{name: name} = init
            id(name)
          type in [:Obv, :Condition] -> val(J.call_expression(id(k), []))
          true -> val(init)
        end
        J.variable_declarator(id(k), init)
      end)
    end
    # OPTIMISE: all templates with calls = 1 can be inlined
    mod = Keyword.get(info, :module)
    tpl_decl = Enum.map(Enum.reverse(calls), fn {k, _v} ->
      ast = Templates.get_ast(mod, k) |> to_ast()
      J.variable_declarator(id(k), ast)
    end)
    J.arrow_function_expression(
      [J.object_pattern([id(:G),id(:C)])],
      [],
      J.block_statement([
        J.variable_declaration(lib_decl ++ var_decl ++ cdn_decl ++ obv_decl ++ tpl_decl, :const),
        J.return_statement(to_ast(ast))
      ])
    )
  end
  def to_ast(%Element{tag: tag, attrs: attrs, content: content}) do
    keyword_prefixer = fn (kw, prefix) ->
      List.wrap(kw)
      |> Enum.map(fn k -> prefix <> to_string(k) end)
      |> Enum.join("")
    end
    str = Enum.reduce(attrs, "", fn {k, v}, acc ->
      case k do
        :class -> acc <> keyword_prefixer.(v, ".")
        :c -> acc <> keyword_prefixer.(v, ".")
        :id -> acc <> keyword_prefixer.(v, "#")
        _ -> acc
      end
    end)
    tag = J.literal(if tag == :div and str != "", do: str, else: Atom.to_string(tag) <> str)
    attrs = do_attrs(attrs)
    args = if is_nil(attrs),   do: [tag], else: [tag, attrs]
    args = if is_nil(content), do: args,  else: args ++ do_args(content)

    J.call_expression(id(:h), args)
  end

  defp do_args(args) do
    if is_list(args) do
      Enum.map(args, &to_ast/1)
    else
      [to_ast(args)]
    end
  end

  defp do_attrs(attrs) do
    attrs = Enum.reduce(attrs, [], fn {k, v}, acc ->
      case k do
        :class -> acc
        :c -> acc
        :id -> acc
        _ ->
          {_, updated} = Keyword.get_and_update(acc, k, fn
            nil -> {nil, v}
            cur when is_list(cur) -> {cur, cur ++ [v]}
            cur -> {cur, [cur, v]}
          end)
          updated
      end
    end)
    if length(attrs) > 0 do
      :lists.reverse(attrs) |> obj()
    else
      nil
    end
  end

  defp obj(kvs), do: obj(kvs, [])
  defp obj([{key, value} | rest], acc) when is_literal(value) do
    obj(rest, acc ++ [J.property(id(key), J.literal(value))])
  end
  defp obj([{key, value} | rest], acc) do
    value = to_ast(value)
    obj(rest, acc ++ [J.property(id(key), value)])
  end
  defp obj([], acc) do
    J.object_pattern(acc)
  end

  defp id(str) when is_binary(str), do: J.identifier(String.to_atom(str))
  defp id(atom) when is_atom(atom), do: J.identifier(atom)
  defp id(kvs) when is_list(kvs) and is_tuple(hd(kvs)) do
    Enum.map(kvs, fn {k, _v} -> id(k) end)
  end
  defp id(atoms) when is_list(atoms) do
    Enum.map(atoms, fn k -> id(k) end)
  end

  # keywords
  defp compute_id?(id) when is_atom(id), do: Atom.to_string(id) |> compute_id?()
  defp compute_id?("if"), do: true
  defp compute_id?("in"), do: true
  defp compute_id?("do"), do: true
  defp compute_id?("var"), do: true
  defp compute_id?("for"), do: true
  defp compute_id?("new"), do: true
  defp compute_id?("try"), do: true
  defp compute_id?("this"), do: true
  defp compute_id?("else"), do: true
  defp compute_id?("case"), do: true
  defp compute_id?("void"), do: true
  defp compute_id?("with"), do: true
  defp compute_id?("enum"), do: true
  defp compute_id?("while"), do: true
  defp compute_id?("break"), do: true
  defp compute_id?("catch"), do: true
  defp compute_id?("throw"), do: true
  defp compute_id?("const"), do: true
  defp compute_id?("yield"), do: true
  defp compute_id?("class"), do: true
  defp compute_id?("super"), do: true
  defp compute_id?("return"), do: true
  defp compute_id?("typeof"), do: true
  defp compute_id?("delete"), do: true
  defp compute_id?("switch"), do: true
  defp compute_id?("export"), do: true
  defp compute_id?("import"), do: true
  defp compute_id?("default"), do: true
  defp compute_id?("finally"), do: true
  defp compute_id?("extends"), do: true
  defp compute_id?("function"), do: true
  defp compute_id?("continue"), do: true
  defp compute_id?("debugger"), do: true
  defp compute_id?("instanceof"), do: true

  # ES6 reserved
  defp compute_id?("implements"), do: true
  defp compute_id?("interface"), do: true
  defp compute_id?("package"), do: true
  defp compute_id?("private"), do: true
  defp compute_id?("protected"), do: true
  defp compute_id?("public"), do: true
  defp compute_id?("static"), do: true
  defp compute_id?("let"), do: true

  # bad practice
  defp compute_id?("null"), do: true
  defp compute_id?("true"), do: true
  defp compute_id?("false"), do: true

  defp compute_id?(str) do
    cl = String.to_charlist(str)
    ch = hd(cl)
    cond do
      (ch >= 0x61 and ch <= 0x7A) or  # a..z
      (ch >= 0x41 and ch <= 0x5A) or  # A..Z
      (ch === 0x24) or (ch === 0x5F)  # $ (dollar) and _ (underscore)
        -> false
      true ->
        # the rest... (for now, we just compute it by default)
        true
    end
  end

  defp val(v) do
    args = case v do
      nil -> []
      _ -> [to_ast(v)]
    end
    J.call_expression(id(:v), args)
  end

  defp txt_to_ast(txt) do
    # TODO: somehow parse the js into elixir ast. I think the easiest will be to spawn node. or call node as a rpc host which can do it.
    txt
  end
end
