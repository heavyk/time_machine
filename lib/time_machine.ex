
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
    elements: TimeMachine.Elements,
    imports: [] # skip importing `component` and `template` from marker (we define our own ones in TimeMachine.Elements)

  # SOON: templates go here!
  # template :toggle_button do
  #   div ".content" do
  #     button [onclick: @toggler!], "toggle"
  #     div do
  #       if @toggler! do
  #         div "ON!"
  #       else
  #         div "off..."
  #       end
  #     end
  #   end
  # end

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
    elements: TimeMachine.Elements,
    imports: []

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
