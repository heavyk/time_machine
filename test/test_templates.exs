defmodule TestTemplates do
  use TimeMachine

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
end
