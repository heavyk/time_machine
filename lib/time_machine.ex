
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
    elements: TimeMachine.Elements,
    imports: [] # skip importing `component` and `template` from marker (we define our own ones in TimeMachine.Elements)


  # borrow some ideas from this: https://dfilatov.github.io/vidom-ui

  # SOON: templates go here!
  template :toggle_button do
    # preset the obv value like this:
    # ~o(is_toggled) = true
    div '.content' do
      button "toggle", [boink: ~o(is_toggled)]
      div do
        if ~o(is_toggled) do
          div "toggled: ON!"
        else
          div "toggled: off..."
        end
      end
    end
  end

  template :press_button do
    div '.content' do
      button "press me", [press: ~o(is_pressed)]
      div do
        if ~o(is_pressed) do
          div "pressed: YES!"
        else
          div "pressed: no..."
        end
      end
    end
  end

  template :adder do
    div '.adder' do
      h2 "button adder"
      div '.buttons' do
        button "++", [boink: ~o(num) <- num + 1]
        button "--", [boink: ~o(num) <- num - 1]
      end
    end
  end

  panel :button_demo do
    # ~o(is_pressed) = true
    # ~o(is_toggled) = true
    fragment do
      h2 "some buttons you can press"
      press_button()
      toggle_button()
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
    elements: TimeMachine.Elements#, imports: []

  # SOON: templates go here!
  template :main do
    div '.content' do
      button [onclick: ~o(toggler)], "toggle"
      div '.display' do
        if ~o(toggler) do
          div '.button', "ON!"
        else
          div '.button', "off..."
        end
      end
    end
  end

  def hello do
    :world
  end
end
