# temporarily this is here. will be pulled out to another project soon as it's working properly


defmodule TimeMachine.Compiler do
  alias Marker.Element
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
  @unary_operator       [ :-, :+, :!, :"~", :typeof, :void, :delete ]

  @binary_operator      [ :==, :!=, :===, :!==, :<, :<=, :>, :>=,
                          :"<<", :">>", :>>>, :+, :-, :*, :/, :%, :|,
                          :^, :&, :in, :instanceof, :"**" ]

  @logical_operator     [ :||, :&& ]

  @assignment_operator  [ :=, :"+=", :"-=", :"*=", :"/=", :"%=",
                          :"<<=", :">>=", :">>>=",
                          :"|=", :"^=", :"&=", :"**=" ]

  @update_operator      [ :++, :-- ]

  @operator @unary_operator ++ @binary_operator ++ @logical_operator ++ @assignment_operator ++ @update_operator

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
  def to_ast({:%, [], [{:__aliases__, _, _} = aliases_, {:%{}, _, map_}]} = value) do
    # this is a strange case where a struct is in elixir ast
    to_ast(Map.new(Keyword.put(map_, :__struct__, Macro.expand(aliases_, __ENV__))))
  end
  def to_ast({op, _meta, [lhs, rhs]} = value) when op in @logical_operator do
    J.logical_expression(op, to_ast(lhs), to_ast(rhs))
  end
  def to_ast({op, _meta, [lhs, rhs]} = value) when op in @binary_operator do
    J.binary_expression(op, to_ast(lhs), to_ast(rhs))
  end

  # def to_ast({op, _meta, [lhs, rhs]} = value) when op in @unary_operator do
  #   J.unary_expression(op, true, to_ast(lhs), to_ast(rhs))
  # end
  def to_ast(%Element.Var{name: name}) do
    J.identifier(String.to_atom(name))
  end
  def to_ast(%Element{tag: :_fragment, content: content}) do
    # for now, we're outputting an array by default, but I imagine that the obv replcement code
    # could replace individual elements, fragments, and null elements just fine. so, maybe we
    # can remove the List.wrap then
    to_ast(List.wrap(content))
  end
  def to_ast(%Element{tag: :_template, content: content}) do
    J.arrow_function_expression([], [], to_ast(content))
  end
  def to_ast(%Element{tag: :_component, content: content}) do
    J.arrow_function_expression([], [], to_ast(content))
  end
  def to_ast(%Element{tag: :_panel, content: content}) do
    J.arrow_function_expression([J.identifier(:d)], [], to_ast(content))
  end
  def to_ast(%Element.If{tag: :_if, test: test_, do: do_, else: else_}) do
    # TODO: incomplete set of functions to convert tests from elixir ast to js ast
    J.conditional_statement(to_ast(test_), to_ast(do_), to_ast(else_))
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
end
