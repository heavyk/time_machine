defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir, which renders to js

  the intent is to show how the interface can be made entirely in elixir, then
  regular js can listen for the events from the interface and do stuff, but the
  interface should be easily renderable by phoenix and operate properly without
  any of the bindings.
  """

  defmacro __using__(opts) do
    # if the application isn't started, ets will not be ready and will spit out the most helpful "argument error" lol
    {:ok, _} = Application.ensure_all_started(:time_machine)
    quote do
      use TimeMachine.Templates
      use TimeMachine.Elements, unquote(opts)
      use Marker,
        compiler: TimeMachine.Compiler,
        elements: TimeMachine.Elements
    end
  end
end
