defmodule TimeMachineTest do
  use ExUnit.Case
  doctest TimeMachine

  test "greets the world" do
    assert TimeMachine.hello() == :world
  end
end
