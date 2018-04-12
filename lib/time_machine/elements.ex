defmodule TimeMachine.Elements do
  use TimeMachine.Logic
  use Marker.Element,
    casing: :lisp,
    tags: [:div, :ul, :li, :a, :img, :input, :label, :button],
    containers: [:template, :component, :panel]

  @transformers [ &TimeMachine.Elements.handle_logic/2 ]

  # some interesting things that can be defined, maybe
  # defmacro left <~> right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
  # defmacro left <|> right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
  # defmacro left <~ right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
  # defmacro left ~> right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end

  # defmacro __using__(opts) do
  #   IO.puts "TimeMachine.Elements! #{inspect opts}"
  # end

  @doc "Obv is a real-time value local to its panel definition"
  defmacro sigil_o({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    name = to_string(ident)
    quote do: %TimeMachine.Logic.Obv{name: unquote(name)}
  end

  @doc "Var is a constant value which exists in the environment - an environmental condition"
  defmacro sigil_v({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    name = to_string(ident)
    quote do: %TimeMachine.Logic.Var{name: unquote(name)}
  end

  @doc "testing something out which is essentially a global obv which exists in its environment"
  defmacro sigil_g({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    name = to_string(ident)
    quote do: %TimeMachine.Logic.Ref{name: unquote(name)}
  end

  @doc "transform this obv into a boolean"
  defmacro sigil_b({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    raise "TODO???"
    # name = to_string(ident)
    # quote do: %TimeMachine.Logic.Transform{name:
    #             %TimeMachine.Logic.Obv{name: unquote(name)},
    #           fun: :boolean}
  end

  @doc "inject a javascript expression directly into the dom at js compile-time*"
  defmacro sigil_j({:<<>>, _, [txt]}, _mods) when is_binary(txt) do
    txt = to_string(txt)
    quote do: %TimeMachine.Logic.Js{content: unquote(txt)}
  end

  @doc false
  def handle_logic(block, info) do
    # perhaps this could be moved to TimeMachine.Logic
    info = Keyword.put_new(info, :ids, [])
    {block, info} = Macro.traverse(block, info, fn
      # PREWALK (going in)
      { :@, meta, [{ name, _, atom }]} = expr, info when is_atom(name) and is_atom(atom) ->
        # static variable to modify how the template is rendered
        name = name |> to_string()
        # IO.puts "@#{name} ->"
        line = Keyword.get(meta, :line, 0)
        cond do
          name |> String.last() == "!" ->
            name = String.trim_trailing(name, "!") |> String.to_atom()
            expr = quote line: line do
              Marker.fetch_assign!(var!(assigns), unquote(name))
            end
            {expr, info}
          true ->
            name = String.to_atom(name)
            assign = quote line: line do
              Access.get(var!(assigns), unquote(name))
            end
            {assign, info}
        end

      expr, info ->
        # IO.puts "prewalk expr: #{inspect expr}"
        {expr, info}
      # END PREWALK
    end, fn
      # POSTWALK (coming back out)
      { sigil, _meta, [{:<<>>, _, [name]}, _]}, info when sigil in [:sigil_o, :sigil_v] ->
        type = case sigil do
          :sigil_v -> :Var
          :sigil_o -> :Obv
        end
        expr =
          {:%, [], [{:__aliases__, [alias: false], [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}
        name = String.to_atom(name)
        ids = info[:ids]
        ids = case t = Keyword.get(ids, name) do
          nil -> Keyword.put(ids, name, type)
          ^type -> ids
          _ -> raise RuntimeError, "#{name} is a #{t}. it cannot be redefined to be a #{type} in the same template"
        end
        info = Keyword.put(info, :ids, ids)
        {expr, info}

      { :if, _meta, [left, right]} = expr, info ->
        ids = Logic.get_ids(expr)
        cond do
          length(ids) > 0 ->
            do_ = Keyword.get(right, :do)
            else_ = Keyword.get(right, :else, nil)
            test_ = Macro.escape(left)
            |> Logic.clean_quoted()
            expr = quote do: %TimeMachine.Logic.If{test: unquote(test_),
                                                  do: unquote(do_),
                                                else: unquote(else_)}
            {expr, info}
          true ->
            {expr, info}
        end
      expr, info ->
        # IO.puts "postwalk expr: #{inspect expr}"
        {expr, info}
      # END postwalk
    end)
    {block, info}
  end
  def handle_logic(block) do
    {block, _info} = handle_logic(block, [])
    block
  end

  # designing a robot to be unhelpful, I think, would be more difficult technically, than to design a helpful one.

  @doc "Define a new template"
  defmacro template(name, do: block) do
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    {block, info} = Enum.reduce(@transformers, {block, [name: name]}, fn t, {blk, info} -> t.(blk, info) end)
    quote do
      def unquote(name)(var!(assigns) \\ []) do
        unquote(use_elements)
        _ = var!(assigns)
        content = unquote(block)
        template_ unquote(info), do: content
      end
    end
  end

  @doc "panel is like a template, but we need to handle more than just the @ assigns"
  defmacro panel(name, do: block) do
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    {block, info} = Enum.reduce(@transformers, {block, [name: name]}, fn t, {blk, info} -> t.(blk, info) end)
    quote do
      def unquote(name)(var!(assigns) \\ []) do
        unquote(use_elements)
        _ = var!(assigns)
        content = unquote(block)
        panel_ unquote(info), do: content
      end
    end
  end

  # @doc "component is a contained ... TODO - work all this out"
  defmacro component(name, do: block) do
    template = String.to_atom(Atom.to_string(name) <> "__template")
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    {block, info} = Enum.reduce(@transformers, {block, [name: name]}, fn t, {blk, info} -> t.(blk, info) end)
    quote do
      defmacro unquote(name)(content_or_attrs \\ nil, maybe_content \\ nil) do
        { attrs, content } = Marker.Element.normalize_args(content_or_attrs, maybe_content, __CALLER__)
        content = quote do: List.wrap(unquote(content))
        assigns = {:%{}, [], [{:__content__, content} | attrs]}
        template = unquote(template)
        quote do
          unquote(__MODULE__).unquote(template)(unquote(assigns))
        end
      end
      @doc false
      def unquote(template)(var!(assigns)) do
        unquote(use_elements)
        _ = var!(assigns)
        content = unquote(block)
        component_ unquote(info), do: content
      end
    end
  end
end
