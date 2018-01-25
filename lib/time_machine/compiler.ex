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

  # convert to javascript

  def to_js(ast) do
    generate(ast)
  end

  # convert to ast

  def to_ast(content) when is_list(content) do
    Enum.map(content, &to_ast/1)
    |> J.array_expression()
  end

  def to_ast(%Element{tag: :_fragment, content: content}) do
    J.arrow_function_expression([], [], to_ast(content))
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

  def to_ast(value) when is_literal(value) do
    J.literal(value)
  end

  # TODO
  # def to_ast(%Element{tag: :_panel, attrs: attrs, content: content}) do
  # 	J.arrow_function_expression([:d], [], to_ast(content))
  # end

  def to_ast(%Element{tag: tag, attrs: attrs, content: content}) do
    tag = J.literal(Atom.to_string(tag))
    args = if length(attrs) > 0, do: [tag, do_attrs(attrs)], else: [tag]
    args = if not is_nil(content), do: args ++ do_args(content), else: args

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
      {_, updated} = Keyword.get_and_update(acc, k, fn
        nil -> {nil, v}
        cur when is_list(cur) -> {cur, cur ++ [v]}
        cur -> {cur, [cur, v]}
      end)
      updated
    end)
    attrs = :lists.reverse(attrs)
    J.object_pattern(do_attrs(attrs, []))
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
end
