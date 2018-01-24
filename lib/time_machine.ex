
defmodule Elements do
  use Marker.Element,
    casing: :lisp,
    tags: [:div, :ul, :li, :a, :img],
    containers: [:panel]

  @doc "panel is like a template, but we need to handle more than just the @ assigns"
  defmacro panel(name, do: block) do
    use_elements = Module.get_attribute(__CALLER__.module, :marker_use_elements)
    block = Marker.handle_assigns(block, false)
    quote do
      def unquote(name)(var!(assigns)) do
        unquote(use_elements)
        _ = var!(assigns)
        content = unquote(block)
        panel_ do: content
      end
    end
  end
end

defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir, which renders to js
  """

  use Marker,
    compiler: TimeMachine.Compiler,
    elements: Elements

  component :foto do
    size = @size
    size = cond do
      size <= 150 -> :s
      size <= 300 -> :m
      size <= 600 -> :l
      size <= 1200 -> :x
    end
    src = "/i/#{size}/#{@id}"
    img src: src, title: @title, alt: @title
  end

  panel :simple_panel do
    ul do
      li "one"
      li "two"
      li "three"
    end
  end

  def hello do
    :world
  end
end
