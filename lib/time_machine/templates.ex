defmodule TimeMachine.Templates do
  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :templates, accumulate: true)
      @on_definition TimeMachine.Templates
      @before_compile TimeMachine.Templates
    end
  end

  def __on_definition__(env, kind, name, args, _guards, _body) do
    if kind == :def and length(args) == 0 and template?(Atom.to_string(name)) do
      Module.put_attribute(env.module, :templates, name)
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    IO.puts "before compile #{mod}"
    quote bind_quoted: [mod: mod] do
      Module.register_attribute(mod, :css, accumulate: true)
      IO.puts "register: #{mod}@css"
      def css(), do: @css
    end
  end

  defp template?(name) when is_binary(name) and binary_part(name, byte_size(name), -10) == "__template", do: true
  defp template?(_), do: false
end
