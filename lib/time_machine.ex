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
      use TimeMachine.Elements
      use Marker,
        compiler: TimeMachine.Compiler,
        elements: TimeMachine.Elements
    end
  end

  use TimeMachine.Elements
  use Marker,
    compiler: TimeMachine.Compiler,
    elements: TimeMachine.Elements


  # borrow some ideas from this: https://dfilatov.github.io/vidom-ui

  template :toggle_button do
    # set the obv value like this: (later, see how this interacts with the way the different panels below set it)
    # ~o(is_toggled) = true
    div '.toggle-button' do
      button "toggle me", [boink: ~o(is_toggled)]
      div '.button-value' do
        if ~o(is_toggled) do
          span "toggled: ON!"
        else
          span "toggled: off..."
        end
      end
    end
  end

  template :press_button do
    div '.press-button' do
      button "press me", [press: ~o(is_pressed)]
      div '.button-value' do
        if ~o(is_pressed) do
          span "pressed: YES!"
        else
          span "pressed: no..."
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

  panel :button_me do
    # define this here and you will see their values are local to this panel.
    # comment their definitions here, and their values will be retrieved from the environment
    # ~o(is_pressed) = true
    # ~o(is_toggled) = true
    div '.buttons' do
      h2 "some buttons you can press"
      press_button()
      toggle_button()
    end
  end

  panel :one_way_binding do
    # we set is_toggled, then set is_pressed to be bound to value of is_toggled
    # you should see that when you press the press the toggle button,
    # the pressed button's default state is the value of toggled
    ~o(is_toggled) = true
    ~o(is_pressed) <~ ~o(is_toggled)
    div '.buttons' do
      h2 "some buttons you can press"
      press_button()
      toggle_button()
    end
  end

  panel :two_way_binding do
    ~o(is_toggled) = true
    ~o(is_toggled) <~> ~o(is_pressed)
    div '.buttons' do
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

  use TimeMachine

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
