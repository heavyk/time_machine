defmodule TimeMachine.Elements do
  use TimeMachine.Logic
  use Marker.Element,
    casing: :lisp,
    tags: [:div, :span, :ul, :li, :a, :img, :input, :label, :button, :h1, :h2, :h3],
    containers: [:template, :component, :panel]

  @transformers [ &TimeMachine.Elements.handle_logic/2 ]

  # unused macros
  # defmacro left <|> right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
  # defmacro __using__(opts) do
  #   IO.puts "TimeMachine.Elements! #{inspect opts}"
  # end

  @doc "one-way bindings, setting the lhs whenever the rhs changes"
  defmacro lhs <~ rhs do
    # IO.puts "<~ #{inspect lhs} #{inspect rhs}"
    # whenever rhs changes, set lhs
    quote do: %TimeMachine.Logic.Bind1{lhs: unquote(lhs), rhs: unquote(rhs)}
  end

  @doc "one-way bindings, setting the rhs whenever the lhs changes"
  defmacro lhs ~> rhs do
    # IO.puts "~> #{inspect lhs} #{inspect rhs}"
    quote do: %TimeMachine.Logic.Bind1{lhs: unquote(rhs), rhs: unquote(lhs)}
  end

  @doc "two-way bindings, beginning with the lhs value"
  defmacro lhs <~> rhs do
    # IO.puts "<~> #{inspect lhs} #{inspect rhs}"
    quote do: %TimeMachine.Logic.Bind2{lhs: unquote(lhs), rhs: unquote(rhs)}
  end

  # @doc "shortcut to define a modify obv on event listener"
  # defmacro lhs <- rhs do
  #   {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, _, [name: name]}]} = Logic.clean_quoted(lhs)
  #   fun = Logic.clean_quoted(rhs) |> Macro.escape()
  #   quote do: %TimeMachine.Logic.Modify{name: unquote(name), type: unquote(type), fun: unquote(fun)}
  # end

  @doc "Obv is a real-time value local to its panel definition"
  defmacro sigil_o({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    name = to_string(ident)
    quote do: %TimeMachine.Logic.Obv{name: unquote(name)}
  end

  @doc "Condition is a real-time value local to its environment"
  defmacro sigil_O({:<<>>, _, [ident]}, _mods) when is_binary(ident) do
    name = to_string(ident)
    quote do: %TimeMachine.Logic.Condition{name: unquote(name)}
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
      |> Keyword.put_new(:pure, true)
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
      { sigil, _meta, [{:<<>>, _, [name]}, _]}, info when sigil in [:sigil_O, :sigil_o, :sigil_v] ->
        type = case sigil do
          :sigil_O -> :Condition
          :sigil_o -> :Obv
          :sigil_v -> :Var
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
        info = info
          |> Keyword.put(:ids, ids)
          |> Keyword.update(:pure, true, fn is_pure -> is_pure and type == :Obv end)
        {expr, info}

      { :if, _meta, [left, right]} = expr, info ->
        ids = Logic.get_ids(expr)
        cond do
          length(ids) > 0 ->
            do_ = Keyword.get(right, :do)
            else_ = Keyword.get(right, :else, nil)
            test_ = Macro.escape(left) |> Logic.clean_quoted()
            expr = quote do: %TimeMachine.Logic.If{test: unquote(test_),
                                                     do: unquote(do_),
                                                   else: unquote(else_)}
            {expr, info}
          true ->
            {expr, info}
        end

      { :=, _meta, [{:%, [], [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}, value]}, info ->
        # IO.puts "assignment: #{inspect type} #{name} = #{inspect value}"
        expr = quote do: %TimeMachine.Logic.Assign{name: unquote(name), type: unquote(type), value: unquote(value)}
        {expr, info}

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
  defmacro template(name, do: block) when is_atom(name) do
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
  defmacro panel(name, do: block) when is_atom(name) do
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
  defmacro component(name, do: block) when is_atom(name) do
    template = String.to_atom(Atom.to_string(name) <> "__template")
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    {block, info} = Enum.reduce(@transformers, {block, [name: name]}, fn t, {blk, info} -> t.(blk, info) end)
    quote do
      defmacro unquote(name)(c1 \\ nil, c2 \\ nil, c3 \\ nil, c4 \\ nil, c5 \\ nil) do
        caller = __CALLER__
        %Marker.Element{attrs: attrs, content: content} =
          %Marker.Element{attrs: [], content: []}
          |> Marker.Element.add_arg(c1, caller)
          |> Marker.Element.add_arg(c2, caller)
          |> Marker.Element.add_arg(c3, caller)
          |> Marker.Element.add_arg(c4, caller)
          |> Marker.Element.add_arg(c5, caller)
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
