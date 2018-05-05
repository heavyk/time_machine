defmodule TimeMachine.Elements do
  use TimeMachine.Logic
  use Marker.Element,
    casing: :lisp,
    tags: [:div, :span, :ul, :li, :a, :p, :b, :i, :br, :img,
           :input, :label, :button, :select, :option,
           :header, :nav, :main, :h1, :h2, :h3, :h4, :hr,
           :html, :head, :meta, :link, :script, :title, :body],
    containers: [:template, :component, :panel]

  @transformers [ &TimeMachine.Logic.handle_logic/2 ]

  # unused macros
  # defmacro left <|> right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
  # defmacro __using__(opts) do
  #   IO.puts "TimeMachine.Elements! #{inspect opts}"
  # end

  @doc "one-way bindings: set lhs whenever the rhs changes"
  defmacro lhs <~ rhs do
    # TODO: raise if lhs is anything other than: ~o() / ~O()
    # TODO: raise if rhs isn't / doesn't contain an obv
    quote do: %TimeMachine.Logic.Bind1{lhs: unquote(lhs), rhs: unquote(rhs)}
  end

  @doc "one-way bindings: set rhs whenever the lhs changes"
  defmacro lhs ~> rhs do
    # TODO: raise if rhs is anything other than: ~o() / ~O()
    # TODO: raise if lhs isn't / doesn't contain an obv
    quote do: %TimeMachine.Logic.Bind1{lhs: unquote(rhs), rhs: unquote(lhs)}
  end

  # TODO: it would be possible to also use the one-way binding syntax as trasform / compute bindings.
  #   eg. ~o(ten_more) <~ ~o(num) + 10
  #       --> %Bind1{lhs: %Transform{in: Obv{name: "num"}, do: [:+, [:num, 10])}, rhs: Obv{name: "ten_more"}}
  #       --> b1(t(num, (num) => num + 10), ten_more)
  #   eg. ~o(sum) <~ ~o(num1) + ~o(num2)
  #       --> %Bind1{lhs: %Transform{in: [Obv{name: "num1"}, Obv{name: "num2"}], do: [:+, [:num1, :num2])}, rhs: Obv{name: "sum"}}
  #       --> b1(c([num1, num2], (num1, num2) => num1 + num2), sum)

  @doc "two-way bindings, beginning with the lhs value"
  defmacro lhs <~> rhs do
    # TODO: raise if lhs or rhs is anything other than: ~o() / ~O()
    quote do: %TimeMachine.Logic.Bind2{lhs: unquote(lhs), rhs: unquote(rhs)}
  end

  # @doc "shortcut to define a modify obv on event listener"
  # defmacro lhs <- rhs do
  #   {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, _, [name: name]}]} = Logic.clean_quoted(lhs)
  #   fun = Logic.clean_quoted(rhs) |> Macro.escape()
  #   quote do: %TimeMachine.Logic.Transmute{name: unquote(name), type: unquote(type), fun: unquote(fun)}
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

  @doc "panel is like a template, but it defines a new js scope (env)"
  defmacro panel(name, do: block) when is_atom(name) do
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    {block, info} = Enum.reduce(@transformers, {block, [name: name, init: []]}, fn t, {blk, info} -> t.(blk, info) end)
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
