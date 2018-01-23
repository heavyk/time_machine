
defmodule Elements do
  use Marker.Element, casing: :lisp, tags: [:div, :ul, :li, :a]
end

defmodule TimeMachine do
  @moduledoc """
  An implementation of a pomodoro timer in elixir
  """

  use Marker,
    compiler: TimeMachine.Compiler,
    elements: Elements

  # template :simple_list do
  #   ul do
  #     li "one"
  #     li "two"
  #     li "three"
  #   end
  # end

  def hello do
    :world
  end
end
