defmodule TestTemplates do
  use TimeMachine

  alias TimeMachine.Logic
  alias Marker.Element

  # the way that these elements are cleaned are indicative of what their content is.
  # clean = a code block or value
  # clean_quoted = escaped quoted expresion
  def clean(ast) when is_list(ast) do
    Enum.map(ast, &clean/1)
  end
  def clean(%Logic.Bind1{rhs: rhs, lhs: lhs}) do
    %Logic.Bind1{rhs: Logic.clean_quoted(rhs), lhs: clean(lhs)}
  end
  def clean(%Logic.Assign{value: value, obv: obv}) do
    %Logic.Assign{value: Logic.clean_quoted(value), obv: clean(obv)}
  end
  def clean(%Logic.Transform{fun: fun, obv: obv}) do
    %Logic.Transform{fun: Logic.clean_quoted(fun), obv: clean(obv)}
  end
  def clean(%Logic.If{test: test_, do: do_, else: else_}) do
    %Logic.If{test: Logic.clean_quoted(test_), do: clean(do_), else: clean(else_)}
  end
  def clean(%Element{tag: :_template, content: content_, attrs: attrs_}) do
    # %Element{tag: tag_, content: clean(content_), attrs: clean(attrs_)}
    %Element{tag: :_template, content: clean(content_), attrs: Keyword.drop(attrs_, [:file, :line, :module]) |> clean()}
  end
  def clean(%Element{tag: tag_, content: content_, attrs: attrs_}) do
    # %Element{tag: tag_, content: clean(content_), attrs: clean(attrs_)}
    %Element{tag: tag_, content: clean(content_), attrs: Keyword.drop(attrs_, [:file, :line, :module, :assigns]) |> clean()}
  end
  def clean(ast) do
    Macro.update_meta(ast, fn (_meta) -> [] end)
  end

  template :tpl_test do
    div "test #{@val}"
  end

  template :tpl_one_item_frag do
    fragment do
      div "test"
    end
  end

  template :tpl_inner_frag do
    num = 1
    fragment do
      div num
      div num + 0.1
      div @num
      div @num + 0.1
    end
  end

  template :tpl_logic_static do
    fragment do
      if @num == 2, do: (div "yay"), else: (div "nope")
      if @num == 2, do: (div "yay")
      div if @num != 2, do: "yay", else: "nope"
      div if @num != 2, do: "yay"
    end
  end

  template :tpl_logic_obv_sometimes do
    fragment do
      if @sometimes, do: (div ~o(num)), else: (div "nope")
      if @sometimes, do: (div ~o(num))
      div if not @sometimes, do: ~o(num), else: "nope"
      div if not @sometimes, do: ~o(num)
    end
  end

  template :tpl_logic_obv do
    fragment do
      if ~o(num) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2, do: (div "yay")
      div if ~o(num) != 2, do: "yay", else: "nope"
      div if ~o(num) != 2, do: "yay"
    end
  end

  template :tpl_logic_var do
    fragment do
      if ~v(num) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2, do: (div "yay")
      div if ~v(num) != 2, do: "yay", else: "nope"
      div if ~v(num) != 2, do: "yay"
    end
  end

  template :tpl_logic_multi_var do
    fragment do
      if ~v(num) == 2 and ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 and ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 and ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 and ~v(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv_var do
    fragment do
      if ~v(num) == 2 and ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 and ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 and ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 and ~o(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv do
    fragment do
      if ~o(num) == 2 and ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 and ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 and ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 and ~o(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_mixed do
    fragment do
      if ~o(oo) == 2, do: (div "yay"), else: (div "nope")
      if ~v(vv) == 2, do: (div "yay"), else: (div "nope")
      if @num == 2, do: (div "yay"), else: (div "nope")
      if ~o(oo) == 2, do: (div "yay")
      if ~v(vv) == 2, do: (div "yay")
      if @num == 2, do: (div "yay")
      div if ~o(oo) != 2, do: "yay", else: "nope"
      div if ~v(vv) != 2, do: "yay", else: "nope"
      div if @num != 2, do: "yay", else: "nope"
      div if ~o(oo) != 2, do: "yay"
      div if ~v(vv) != 2, do: "yay"
      div if @num != 2, do: "yay"
    end
  end

  template :tpl_logic_if do
    if ~o(num) == 1 do
      div "one"
    else
      if ~o(num) == 2 do
        div "two"
      else
        if ~o(num) == 3 do
          div "three"
        else
          div "nope"
        end
      end
    end
  end

  template :tpl_inner_tpl do
    div do
      tpl_obv(num: 1)
      tpl_logic_mixed(lala: 1234)
    end
  end

  template :tpl_logic_cond do
    cond do
      ~o(num) == 1 -> div "one"
      ~o(num) == 2 -> div "two"
      ~o(num) == 3 -> div "three"
      true -> div "nope"
    end
  end

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

  panel :pnl_logic_var do
    fragment do
      if ~v(num) == 2 and ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 and ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 and ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 and ~v(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv_var do
    fragment do
      if ~v(num) == 2 and ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 and ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 and ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 and ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_cdn do
    fragment do
      if ~c(num) == 2 and ~c(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~c(num) == 2 and ~c(mun) == 2, do: (div "yay")
      div if ~c(num) != 2 and ~c(mun) == 2, do: "yay", else: "nope"
      div if ~c(num) != 2 and ~c(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv_cdn do
    fragment do
      if ~c(num) == 2 and ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~c(num) == 2 and ~o(mun) == 2, do: (div "yay")
      div if ~c(num) != 2 and ~o(mun) == 2, do: "yay", else: "nope"
      div if ~c(num) != 2 and ~o(mun) == 2, do: "yay"
    end
  end

  # this is kinda a thing, because both ~o(num) and ~o(mun) are used in the panel, but neither of them are defined
  # so, that means that this is an impure panel and both of the values of those come from the containing environment
  # and therefore need to be cleaned...
  # by default h() should clean up that obv listener when its cleanup function is called..
  # TODO: just ensure h's cleanup is in fact called
  panel :pnl_logic_obv do
    fragment do
      if ~o(num) == 2 and ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 and ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 and ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 and ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_obv_assign do
    ~o(num) = 2 + 2
    div "num is", ~o(num)
  end

  panel :pnl_inner_obv_tpl do
    ~o(num) = 4
    div do
      tpl_logic_obv()
    end
  end

  panel :pnl_inner_inner_tpl do
    ~o(num) = 4
    div do
      tpl_inner_tpl()
    end
  end

  panel :pnl_inner_impure_tpl do
    ~o(num) = 4
    div do
      tpl_logic_multi_obv_var()
    end
  end

  template :tpl_transform_inline do
    div do
      input type: "number", value: ~o(num)
      " + 10 = "
      ~o(num) + 10
    end
  end

  panel :pnl_transform_assign do
    # num will inherit the value of any lower scope, if it exists...
    # if not, the input box below will initialise it to 0
    ~o(sum) <~ ~o(num) + 10
    div do
      input type: "number", value: ~o(num)
      " + 10 = "
      ~o(sum)
    end
  end

  template :tpl_compute_inline do
    div do
      input type: "number", value: ~o(num1) # should initialise to 0 (or the assigned value of the env)
      " + "
      input type: "number", value: ~o(num2) # same
      " = "
      ~o(num1) + ~o(num2)
    end
  end

  panel :pnl_compute_assign do
    ~o(num1) = 10
    ~o(num2) = 20
    ~o(sum) <~ ~o(num1) + ~o(num2)
    div do
      input type: "number", value: ~o(num1)
      " + "
      input type: "number", value: ~o(num2)
      " = "
      ~o(sum)
    end
  end

  panel :pnl_one_way_biniding do
    ~o(num1) = 10
    ~o(num2) = 20
    ~o(sum1) <~ ~o(num1) + ~o(num2)
    ~o(sum2) <~ ~o(sum1)
    div do
      input type: "number", value: ~o(num1)
      " + "
      input type: "number", value: ~o(num2)
      " = "
      ~o(sum1)
      " = "
      ~o(sum2)
    end
  end

  panel :pnl_two_way_binding do
    ~o(num1) <~> ~o(num2)
    div do
      input type: "number", value: ~o(num1)
      " * "
      input type: "number", value: ~o(num2)
      " * "
      input type: "number", value: ~o(num3)
      " = "
      (~o(num1) * ~o(num2) * ~o(num3))
    end
  end

  #
  # `[[obv]] = [[literal]]` initialises [[obv]] to the value of [[literal]]
  #   - cannot happen in a template. must happen in a scope definition (eg. a panel)
  #   - can only define a variable in a scope's initial value (and that value must be a literal)
  #   - must be found before the last line of a template
  #
  # `[[obv]] <- [[expr]]` is a one-shot asssignment of the value of [[expr]] into [[obv]]
  #   - if found as an element event listener, it'll save the result of expression into [[obv]] whenever fired
  #   - cannot be found before the last line of a template. if so, recommend its conversion to an initialisation or transformation
  #   - [[expr]] can be a literal value, or any other mix of any real-time or otherwise values
  #   - can be executed in a conditionally (eg. inside of an if or cond statement)
  #
  # `[[obv]] <~ [[expr]]` updates [[obv]] in real-time, any time the value of [[expr]] changes
  #   - if found before the last line of a template:
  #     - signifies the definition of a value as the real-time computation of [[expr]
  #     - or, it signifies a 1-way binding if [[expr]] is another [[obv]]
  #   - must be found before the last line of a template
  #   - will raise an error if [[expr]] is a literal
  #
  # `[[obv]] <~> [[obv]]` two-way binding between obvs
  #   - neither side can be anything other than [[obv]]
  #   - must be found before the last line of a template
  #   - cannot be conditionally assigned (this restriction can potentially be relaxed - as could be otherwise)
  #

  # TODO: convert me to a proper test...
  # the boink/pulse arrow needs testing
  # also without an arrow -- tpl_boinker
  template :tpl_cdn do
    div '.tpl_cdn' do
      "condition (lala) is:"
      ~c(lala)
      " + (num) = "
      ~o(sum)
    end
  end

  template :tpl_obv do
    div '.tpl_obv' do
      "num is:"
      ~o(num)
      div '.click' do
        button "num++", boink: ~o(num) <- ~o(num) + 1
        button "num--", boink: ~o(num) <- ~o(num) - 1
      end
    end
  end

  template :tpl_boink do
    div '.tpl_boink' do
      div '.boink' do
        span "boinked: ", (if ~o(boinked), do: "YES!", else: "no...")
        button "boink", boink: ~o(boinked)
      end
      div '.press' do
        span "pressed: ", (if ~o(pressed), do: "YES!", else: "no...")
        button "press me", press: ~o(pressed)
      end
    end
  end

  template :tpl_words do
    div '.tpl_words' do
      div '.word-input' do
        input type: "text", value: ~o(w1), placeholder: "type a name..."
        span " and "
        input type: "text", value: ~o(w2), placeholder: "type a name..."
      end
      div (b ~o(w1)), " goes to the market"
      div (b ~o(w2)), " stays home"
      div (b ~o(w1)), " and ", (b ~o(w2)), " are not at the zoo"
    end
  end

  template :tpl_select do
    div '.tpl_select' do
      "selector: "
      select '.selector', value: ~o(selected) do
        option "please select...", disabled: true, selected: true, value: ""
        option "one", value: 1
        option "two", value: 2
        option "three", value: 3
        option "four", value: 4
      end
      input type: "text", value: ~o(selected), placeholder: "nothing selected yet..."
      " selected: "
      (b ~o(selected))
    end
  end

  # a recreation of the example in /src/plugins/plugger.js
  panel :pnl_plugin_demo do
    ~o(num) = 11
    ~o(sum) <~ ~o(num) + ~c(lala)
    ~o(boinked) = false
    ~o(pressed) = false
    div do
      h1 "simple plugin demo"
      hr()
      h3 "conditions, numbers, and transformations"
      tpl_cdn()
      tpl_obv()
      hr()
      h3 "mouse / touch events"
      tpl_boink()
      hr()
      h3 "text input"
      tpl_words()
      hr()
      h3 "select boxes"
      tpl_select()
    end
  end
end
