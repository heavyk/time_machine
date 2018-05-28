defmodule TimeMachine.TemplateCompiler do
  alias TimeMachine.Templates
  def __on_definition__(_env, _kind, name, args, _guards, _body) do
    IO.puts "defining: #{name}"
    case args do
      [{:\\, _, [{:var!, _, [{:assigns, _, TimeMachine.Elements}]}, []]}] ->
        # this is pretty unused right now.
        nil
      _args_ -> nil
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    templates = Module.get_attribute(mod, :templates)
    panels = Module.get_attribute(mod, :panels)
    components = Module.get_attribute(mod, :components)
    use_elements = Module.get_attribute(mod, :marker_use_elements)
    # TODO: allow this to be configured easier
    transformers = Module.get_attribute(mod, :transformers) || [ &TimeMachine.Logic.handle_logic/2 ]

    enum_defs = quote do
      def templates(), do: @templates
      def panels(), do: @panels
      def components(), do: @components
      def css(), do: @css
    end

    template_defs = Enum.map(templates, fn name ->
      block = Templates.get_block(mod, name)
      info = [name: name, module: mod]
      {block, info} = Enum.reduce(transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
      Templates.set_info(mod, name, info)
      quote do
        def unquote(name)(var!(assigns) \\ []) do
          unquote(use_elements)
          _ = var!(assigns)
          block = unquote(block)
          ast = template_ unquote(info), do: block
          Templates.set_ast(unquote(mod), unquote(name), var!(assigns), ast)
          ast
        end
      end
    end)

    panel_defs = Enum.map(panels, fn name ->
      block = Templates.get_block(mod, name)
      info = [name: name, module: mod, init: []]
      {block, info} = Enum.reduce(transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
      Templates.set_info(mod, name, info)
      quote do
        def unquote(name)(var!(assigns) \\ []) do
          unquote(use_elements)
          _ = var!(assigns)
          block = unquote(block)
          ast = panel_ unquote(info), do: block
          Templates.set_ast(unquote(mod), unquote(name), var!(assigns), ast)
          ast
        end
      end
    end)

    component_defs = Enum.map(components, fn name ->
      template = String.to_atom(Atom.to_string(name) <> "__template")
      block = Templates.get_block(mod, name)
      info = [name: name, module: mod, init: []]
      {block, info} = Enum.reduce(transformers, {block, info}, fn t, {blk, info} -> t.(blk, info) end)
      Templates.set_info(mod, name, info)
      quote do
        @doc false
        def unquote(template)(var!(assigns) \\ []) do
          unquote(use_elements)
          _ = var!(assigns)
          block = unquote(block)
          ast = component_ unquote(info), do: block
          Templates.set_ast(unquote(mod), unquote(name), var!(assigns), ast)
          ast
        end
      end
    end)

    [enum_defs, template_defs, panel_defs, component_defs]
  end
end
