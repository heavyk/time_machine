defmodule TimeMachine.Elements do
  alias TimeMachine.Templates

  use TimeMachine.Logic
  use Marker.Element,
    casing: :lisp,
    using: false,
    tags: [:div, :span, :ul, :li, :a, :p, :b, :i, :br, :img,
           :input, :label, :button, :select, :option,
           :header, :nav, :main, :h1, :h2, :h3, :h4, :hr,
           :html, :head, :meta, :link, :script, :title, :body],
    containers: [:template, :component, :panel]

  @transformers [ &TimeMachine.Logic.handle_logic/2 ]

  # by default, Marker will essentially make the same using function, but without the register_attribute calls.
  # this is to allow my custom definitions of containers to be able to rely on that module attribute
  defmacro __using__(opts) do
    caller = __CALLER__
    tags = opts[:tags] || [:div]
    tags = Macro.expand(tags, caller)
    ambiguous_imports = Marker.Element.find_ambiguous_imports(tags)
    quote do
      import Kernel, except: unquote(ambiguous_imports)
      import unquote(__MODULE__)
    end
  end

  # designing a robot to be unhelpful, I think, would be more difficult technically, than to design a helpful one.

  @doc "Define a new template"
  defmacro template(name, do: block) when is_atom(name) do
    caller = __CALLER__
    mod = caller.module
    use_elements = Module.get_attribute(mod, :marker_use_elements)
    info = [name: name, module: mod]
    {block, info} = Enum.reduce(@transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
    Templates.define(mod, name, :template, info)
    Module.put_attribute(mod, :templates, name)
    quote do
      def unquote(name)(var!(assigns) \\ []) do
        unquote(use_elements)
        _ = var!(assigns)
        block = unquote(block)
        ast = template_ unquote(info), do: block
        Templates.insert(unquote(mod), unquote(name), var!(assigns), ast)
        ast
      end
    end
  end

  @doc "panel is like a template, but it defines a new js scope (env)"
  defmacro panel(name, do: block) when is_atom(name) do
    caller = __CALLER__
    mod = caller.module
    use_elements = Module.get_attribute(mod, :marker_use_elements)
    info = [name: name, module: mod, init: []]
    {block, info} = Enum.reduce(@transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
    Templates.define(mod, name, :panel, info)
    Module.put_attribute(mod, :panels, name)
    quote do
      def unquote(name)(var!(assigns) \\ []) do
        unquote(use_elements)
        _ = var!(assigns)
        block = unquote(block)
        ast = panel_ unquote(info), do: block
        Templates.insert(unquote(mod), unquote(name), var!(assigns), ast)
        ast
      end
    end
  end

  # @doc "component is a contained ... TODO - work all this out"
  defmacro component(name, do: block) when is_atom(name) do
    caller = __CALLER__
    mod = caller.module
    template = String.to_atom(Atom.to_string(name) <> "__template")
    use_elements = Module.get_attribute(mod, :marker_use_elements)
    info = [name: name, module: mod]
    {block, info} = Enum.reduce(@transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
    Templates.define(mod, name, :component, info)
    Module.put_attribute(mod, :components, name)
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
      def unquote(template)(var!(assigns) \\ []) do
        unquote(use_elements)
        _ = var!(assigns)
        block = unquote(block)
        ast = component_ unquote(info), do: block
        Templates.insert(unquote(mod), unquote(name), var!(assigns), ast)
        ast
      end
    end
  end

  # ambiente
  # poem / plugin
end
