defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir, which renders to js

  the intent is to show how the interface can be made entirely in elixir, then
  regular js can listen for the events from the interface and do stuff, but the
  interface should be easily renderable by phoenix and operate properly without
  any of the bindings.
  """

  defmacro __using__(_) do
    quote do
      use TimeMachine.Templates
      use TimeMachine.Elements
      use Marker,
        compiler: TimeMachine.Compiler,
        elements: TimeMachine.Elements
    end
  end
end
