
defmodule TimeMachine.Elements do
  use Marker.Element,
    casing: :lisp,
    tags: [:div, :ul, :li, :a, :img, :input, :label, :button],
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


  @doc """
  sigil ~h is a shortcut to create elements

  not that useful because no other attrs can be added, other than class or id.

  ## Examples

  iex> ~h/input.input-group.form/
  %Marker.Element{
    attrs: [class: :"input-group", class: :form],
    content: nil,
    tag: :input
  }
  """
  defmacro sigil_h({:<<>>, _, [binary]}, _attrs) when is_binary(binary) do
    matches = Regex.split(~r/[\.#]?[a-zA-Z0-9_:-]+/, binary, include_captures: true)
    |> Enum.reject(fn s -> byte_size(s) == 0 end)
    tag = case List.first(matches) do
      "." <> _ -> :div
      "#" <> _ -> :div
      tag -> String.to_atom(tag)
    end
    attrs = :lists.reverse(Enum.reduce(matches, [], fn i, acc ->
      case i do
        "." <> c -> [{:class, String.to_atom(c)} | acc]
        "#" <> c -> [{:id, String.to_atom(c)} | acc]
        _ -> acc
      end
    end))
    # quote do: %Marker.Element{tag: unquote(tag), attrs: unquote(attrs)}
    quote do: unquote(tag)(unquote(attrs))
  end

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
end

defmodule TimeMachine.Templates do
  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :templates, accumulate: true)

      @on_definition TimeMachine.Templates
      @before_compile TimeMachine.Templates
    end
  end

  def __on_definition__(env, kind, name, args, _guards, _body) do
    if kind == :def and template?(Atom.to_string(name)) and length(args) == 0 do
      Module.put_attribute(env.module, :templates, name)
    end
  end

  defp template?(name) when is_binary(name) and binary_part(name, byte_size(name), -10) == "__template", do: true
  defp template?(_), do: false
end

defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir, which renders to js

  the intent is to show how the interface can be made entirely in elixir, then
  regular js can listen for the events from the interface and do stuff, but the
  interface should be easily renderable by phoenix and operate properly without
  any of the bindings.
  """

  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements

  # SOON: templates go here!
  template :toggle_button do
    div ".content" do
      button [onclick: @toggler!], "toggle"
      div do
        if @toggler! do
          div "ON!"
        else
          div "off..."
        end
      end
    end
  end

  def hello do
    :world
  end
end

defmodule Toggler do
  @moduledoc """
  A simple demonstration of a html interface written in elixir, which renders to js
  """

  @css '''
  .content {
    border: solid 1px #4a4;
  }
  '''

  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements

  # SOON: templates go here!
  template :main do
    div ".content" do
      button [onclick: @toggler!], "toggle"
      div do
        if @toggler! do
          div "ON!"
        else
          div "off..."
        end
      end
    end
  end

  def hello do
    :world
  end
end
