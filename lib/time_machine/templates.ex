defmodule TimeMachine.Templates do
  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :templates, accumulate: true)
      Module.register_attribute(__MODULE__, :css, accumulate: true)
      @on_definition TimeMachine.Templates
      @before_compile TimeMachine.Templates
    end
  end

  def __on_definition__(env, _kind, name, args, _guards, _body) do
    case args do
      [{:\\, _, [{:var!, _, [{:assigns, _, TimeMachine.Elements}]}, []]}] ->
        # IO.puts "define template: #{name} in #{env.module}"
        Module.put_attribute(env.module, :templates, name)
      _ -> nil
    end
  end

  defmacro __before_compile__(env) do
    # IO.puts "before compile #{mod}"
    quote bind_quoted: [mod: env.module] do
      # IO.puts "register: #{mod}@css"
      # IO.puts "register: #{mod}.templates"
      def templates(), do: @templates
      def template?(t), do: t in @templates
      def css(), do: @css
    end
  end
end
