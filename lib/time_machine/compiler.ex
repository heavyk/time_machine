# temporarily this is here. will be pulled out to another project soon as it's working properly


defmodule TimeMachine.Compiler do
  alias Marker.Element
  alias TimeMachine.Logic
  alias ESTree.Tools.Builder, as: J
  # alias ESTree.Tools.Generator

  defdelegate generate(ast), to: ESTree.Tools.Generator

  defguard is_literal(v) when is_binary(v) or is_number(v) or is_atom(v) or is_boolean(v) or is_nil(v)

  def compile(content) when is_list(content) do
    Enum.map(content, &compile/1)
  end
  def compile(%Element{tag: tag, attrs: attrs, content: content}) do
    quote do: %Element{tag: unquote(tag), attrs: unquote(attrs), content: unquote(content)}
  end
  def compile(value) do
    TimeMachine.Encoder.encode(value)
    # value
  end
  # def compile(content) do
  #   quote do: unquote(content)
  # end

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
  def to_ast({op, _meta, [lhs, rhs]}) when op in @unary_operator do
    J.unary_expression(op, true, to_ast(lhs), to_ast(rhs))
  end
  def to_ast(%Logic.Js{content: content}) do
    content = txt_to_ast(content) # this should do variable name transformations on this js' identifiers, too
    {:safe, content}
  end
  def to_ast(%Logic.Var{name: name}) do
    name # Namespaceman.get(el)
    |> String.to_atom()
    |> J.identifier()
  end
  def to_ast(%Logic.Obv{name: name}) do
    name # Namespaceman.get(el)
    |> String.to_atom()
    |> J.identifier()
  end
  def to_ast(%Logic.Condition{name: name}) do
    name # Namespaceman.get(el)
    |> String.to_atom()
    |> J.identifier()
  end
  def to_ast(%Logic.Ref{name: name}) do
    J.member_expression(J.identifier(:G), to_ast(name), true)
  end

  def to_ast(%Logic.If{tag: :_if, test: test_, do: do_, else: else_}) do
    obvs = TimeMachine.Elements.get_vars(test_, [:Obv, :Ref])
    stmt = J.conditional_statement(to_ast(test_), to_ast(else_), to_ast(do_))
    case length(obvs) do
      0 -> stmt
      1 ->
        {k, _v} = hd(obvs)
        fun = J.arrow_function_expression([J.identifier(k)], [], stmt)
        J.call_expression(J.identifier(:t), [J.identifier(k), fun])
      _ ->
        keys = Keyword.keys(obvs) |> Enum.map(fn k -> J.identifier(k) end)
        fun = J.arrow_function_expression(keys, [], stmt)
        J.call_expression(J.identifier(:c), [J.array_expression(keys), fun])
    end
  end
  def to_ast(%Element{tag: :_fragment, content: content}) do
    # for now, we're outputting an array by default, but I imagine that the obv replcement code
    # could replace individual elements, fragments, and null elements just fine. so, maybe we
    # can remove the List.wrap then
    to_ast(List.wrap(content))
  end
  def to_ast(%Element{tag: :_template, content: content, attrs: attrs}) do
    obvs = Enum.reduce(attrs, [], fn {k, v}, acc ->
      case v do
        :Obv -> [J.identifier(k) | acc]
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
  def to_ast(%Element{tag: :_panel, content: content, attrs: _info}) do
    # TODO: do something with "info" .. TBD :)
    obvs = TimeMachine.Elements.get_vars(content, :Obv)
    |> Enum.map(fn {k, _} -> J.identifier(k) end)
    args = cond do
      length(obvs) > 0 -> [J.object_pattern(obvs)]
      true -> []
    end
    J.arrow_function_expression(args, [], to_ast(content))
  end
  def to_ast(%Element{tag: tag, attrs: attrs, content: content}) do
    str = Enum.reduce(attrs, "", fn {k, v}, acc ->
      case k do
        :class -> acc <> keyword_prefixer(v, ".")
        :c -> acc <> keyword_prefixer(v, ".")
        :id -> acc <> keyword_prefixer(v, "#")
        _ -> acc
      end
    end)
    tag = J.literal(if tag == :div and str != "", do: str, else: Atom.to_string(tag) <> str)
    attrs = do_attrs(attrs)
    args = if is_nil(attrs),   do: [tag], else: [tag, attrs]
    args = if is_nil(content), do: args,  else: args ++ do_args(content)

    J.call_expression(J.identifier(:h), args)
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
      :lists.reverse(attrs)
      |> do_attrs([])
      |> J.object_pattern()
    else
      nil
    end
  end
  defp do_attrs([{key, value} | rest], acc) when is_literal(value) do
    do_attrs(rest, acc ++ [J.property(J.identifier(key), J.literal(value))])
  end
  defp do_attrs([{key, value} | rest], acc) do
    value = to_ast(value)
    do_attrs(rest, acc ++ [J.property(J.identifier(key), value)])
  end
  defp do_attrs([], acc) do
    acc
  end

  defp keyword_prefixer(kw, prefix) do
    List.wrap(kw)
    |> Enum.map(fn k -> prefix <> to_string(k) end)
    |> Enum.join("")
  end

  defp txt_to_ast(txt) do
    # TODO: somehow parse the js into elixir ast. I think the easiest will be to spawn node. or call node as a rpc host which can do it.
    txt
  end
end
