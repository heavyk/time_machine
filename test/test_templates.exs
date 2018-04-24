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
  def clean(%Element{tag: tag_, content: content_, attrs: attrs_}) do
    %Element{tag: tag_, content: clean(content_), attrs: clean(attrs_)}
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
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv_var do
    fragment do
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  template :tpl_logic_multi_obv do
    fragment do
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay"
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
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~v(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~v(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv_var do
    fragment do
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~v(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~v(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_logic_obv do
    fragment do
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay"), else: (div "nope")
      if ~o(num) == 2 && ~o(mun) == 2, do: (div "yay")
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay", else: "nope"
      div if ~o(num) != 2 && ~o(mun) == 2, do: "yay"
    end
  end

  panel :pnl_obv_assign do
    ~o(num) = 4
    div "num is", ~o(num)
  end

  panel :pnl_inner_tpl do
    ~o(num) = 4
    div do
      tpl_logic_obv()
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
    ~o(sum) <~ ~o(nuum) + 10
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

  # TODO: convert me to a proper test...
  # the boink/pulse arrow needs testing
  # also without an arrow -- tpl_boinker
  template :tpl_adder do
    div '.adder' do
      h2 "button adder"
      div '.buttons' do
        button "++", [boink: ~o(num) <- num + 1]
        button "--", [boink: ~o(num) <- num - 1]
      end
    end
  end
end
