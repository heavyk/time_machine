defmodule TimeMachine.Compiler do
  alias Marker.Element
  alias TimeMachine.Logic
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

  @logical_operator     [ :||, :&& ]

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
    Enum.map(content, &to_ast/1)
    |> J.array_expression()
  end
  def to_ast(value) when is_literal(value) do
    J.literal(value)
  end
  def to_ast({:%, [], [aliases_, {:%{}, _, map_}]}) do
    {:__aliases__, [alias: mod_a], mod} = aliases_
    mod = cond do
      mod_a == false && is_list(mod) -> Module.concat(mod)
      mod_a != false && is_atom(mod_a) -> mod_a
    end
    struct(mod, map_)
    |> to_ast()
  end
  def to_ast({op, _meta, [lhs, rhs]}) when op in @logical_operator do
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
    # Namespaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Obv{name: name}) do
    # Namespaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Condition{name: name}) do
    # Namespaceman.get(el)
    id(name)
  end
  def to_ast(%Logic.Ref{name: name}) do
    J.member_expression(id(:G), to_ast(name), true)
  end
  def to_ast(%Logic.Modify{obv: obv, fun: fun}) do
    %_type{name: name} = obv
    fun = Macro.expand(fun, __ENV__)
    fun = J.arrow_function_expression([id(name)], [], to_ast(fun))
    J.call_expression(id(:m), [id(name), fun])
  end

  def to_ast(%Logic.If{tag: :_if, test: test_, do: do_, else: else_}) do
    obvs = Logic.get_ids(test_, [:Obv, :Ref])
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
  def to_ast(%Element{tag: :_panel, content: content, attrs: info}) do
    lib = [:h,:t,:c,:v] # TODO: for now, we define all of them, but in the future, only defnine the ones that are required
    cods = Logic.get_ids(content, [:Condition, :Var]) # TODO: also need to do this for each inner impure_tpl as well.
    lib_decl = [J.variable_declarator(J.object_pattern(id(lib)), id(:G))]
    cod_decl = case length(cods) do
      0 -> []
      _ -> [J.variable_declarator(J.object_pattern(id(cods)), id(:C))]
    end
    impure_tpls = [] # TODO: define all non-pure inner templates inside of the panel here...
    # TODO: need a way to find inner template references (and subquently their cod/var)
    obvs = Logic.get_ids(content, :Obv)
    # ids = Keyword.get(info, :ids, [])
    obv_init = Keyword.get(info, :init, [])
    obvs = case Keyword.get(info, :pure) do
      # true -> obvs
      _ -> Keyword.merge(obvs, obv_init)
    end
    # IO.puts "obvs: #{inspect obvs}"
    obv_decl = case length(obvs) do
      0 -> []
      _ -> Enum.map(obvs, fn {k, _type} ->
        J.variable_declarator(id(k), val(Keyword.get(obv_init, k)))
      end)
    end
    J.function_declaration(
      id(info[:name]),
      [J.object_pattern([id(:G),id(:C)])],
      [],
      J.block_statement([
        J.variable_declaration(lib_decl ++ cod_decl ++ obv_decl ++ impure_tpls, :const),
        J.return_statement(to_ast(content))
      ]),
      false, # is_generator - someday, we should make async panels :)
      false
    )
    J.arrow_function_expression(
      [J.object_pattern([id(:G),id(:C)])],
      [],
      J.block_statement([
        J.variable_declaration(lib_decl ++ cod_decl ++ obv_decl ++ impure_tpls, :const),
        J.return_statement(to_ast(content))
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
  defp id(atoms) when is_list(atoms) and is_atom(hd(atoms)) do
    Enum.map(atoms, fn k -> J.identifier(k) end)
  end
  defp id(kvs) when is_list(kvs) do
    Enum.map(kvs, fn {k, _v} -> J.identifier(k) end)
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
