
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

  defmacro el(e, content_or_attrs \\ nil, maybe_content \\ nil) do
    # quote do
      compiler = Module.get_attribute(__CALLER__.module, :marker_compiler) || Marker.Compiler
      { attrs, content } = Marker.Element.normalize_args(content_or_attrs, maybe_content, __CALLER__)
      %Marker.Element{tag: e.tag, attrs: attrs, content: content}
      |> compiler.compile()
    # end
  end

  defmacro sigil_h({:<<>>, _, [binary]}, _attrs) when is_binary(binary) do
    # IO.inspect __CALLER__
    m = Regex.split(~r/[\.#]?[a-zA-Z0-9_:-]+/, binary, include_captures: true)
    m = Enum.reject(m, fn s -> byte_size(s) == 0 end)
    tag = case List.first(m) do
      "." <> _ -> :div
      "#" <> _ -> :div
      tag -> String.to_atom(tag)
    end
    attrs = :lists.reverse(Enum.reduce(m, [], fn i, acc ->
      case i do
        "." <> c -> [{:class, String.to_atom(c)} | acc]
        "#" <> c -> [{:id, String.to_atom(c)} | acc]
        _ -> acc
      end
    end))
    # quote do: %Marker.Element{tag: unquote(tag), attrs: unquote(attrs)}
    quote do: unquote(tag)(unquote(attrs))
  end

  # defmacro left $$ right do
  #   IO.puts "yay! #{inspect left} #{inspect right}"
  # end
end

defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir, which renders to js

  the intent is to show how the interface can be made entirely in elixir, then
  regular js can listen for the events from the interfce and do stuff, but the
  interface should be easily renderable by phoenix and operate properly without
  any of the bindings.
  """

  use Marker,
    compiler: TimeMachine.Compiler,
    elements: Elements

  # SOON: templates go here!
  template :frame do
    (~h/div.content/a)
  end

  def hello do
    :world
  end
end
