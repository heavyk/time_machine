defmodule ElementsTest do
  use ExUnit.Case

  import TestTemplates
  alias Marker.Element, as: E
  alias TimeMachine.Logic
  require Logic

  use TimeMachine

  doctest TimeMachine.Elements

  test "elements" do
    assert (div "one") == %E{tag: :div, content: "one"}
    assert (div [lala: 1234], "one") == %E{tag: :div, content: "one", attrs: [lala: 1234]}
    assert (div [a: 1, a: 2, a: 3, a: 4]) == %E{tag: :div, attrs: [a: 1, a: 2, a: 3, a: 4]}

    # test selectors instead of a kw-list
    assert (div 'lala.c1') == %E{tag: :div, attrs: [class: :c1]}
    assert (div '.c1') == %E{tag: :div, attrs: [class: :c1]}
    assert (div '.c1.c2.c3') == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3]}
    assert (div '.c1.c2.c3#id') == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3, id: :id]}
    assert (div '#id', do: "lala") == %E{tag: :div, attrs: [id: :id], content: "lala"}

    # ensure binaries are never parsed as selectors
    assert (div "...") == %E{tag: :div, content: "..."}
    assert (div "#1") == %E{tag: :div, content: "#1"}

    assert ~h/div.c1/ == %E{tag: :div, attrs: [class: :c1]}
    assert ~h/.c1/ == %E{tag: :div, attrs: [class: :c1]}
    assert ~h/.c1.c2.c3/ == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3]}
    assert ~h/.c1.c2.c3#id/ == %E{tag: :div, attrs: [class: :c1, class: :c2, class: :c3, id: :id]}
  end

  test "templates" do
    assert tpl_test([val: 1234]) |> clean()
     ==
    %E{tag: :_template,
     attrs: [pure: true, ids: [], name: :tpl_test],
   content: %E{tag: :div,
           content: "test 1234"}}
    |> clean()
  end

  test "fragments" do
    assert tpl_one_item_frag() |> clean()
     ==
      %E{tag: :_template, content: %E{tag: :_fragment, content:
        %E{tag: :div, content: "test"}
      }, attrs: [pure: true, ids: [], name: :tpl_one_item_frag]}
      |> clean()

    assert tpl_inner_frag([num: 11]) |> clean()
     ==
      %E{tag: :_template, content: %E{tag: :_fragment, content: [
        %E{tag: :div, content: 1},
        %E{tag: :div, content: 1.1},
        %E{tag: :div, content: 11},
        %E{tag: :div, content: 11.1}
      ]}, attrs: [pure: true, ids: [], name: :tpl_inner_frag]}
      |> clean()
  end

  test "components" do
    assert foto size: 180, id: "lol", title: "an image" |> clean()
     ==
      %E{tag: :_component, content:
        %E{tag: :img, attrs: [src: "/i/m/lol",
                              title: "an image",
                              alt: "an image"]},
         attrs: [pure: true, ids: [], name: :foto]}
      |> clean()
  end

  test "static logic" do
    assert tpl_logic_static([num: 1]) |> clean()
     ==
      %E{content:
        %E{content: [
          %E{content: "nope", tag: :div},
          nil,
          %E{content: "yay", tag: :div},
          %E{content: "yay", tag: :div}
        ], tag: :_fragment
      }, tag: :_template, attrs: [pure: true, ids: [], name: :tpl_logic_static]}
      |> clean()

    assert tpl_logic_static([num: 2]) |> clean()
     ==
      %E{content:
        %E{content: [
          %E{content: "yay", tag: :div},
          %E{content: "yay", tag: :div},
          %E{content: "nope", tag: :div},
          %E{content: nil, tag: :div}
        ], tag: :_fragment
      }, tag: :_template, attrs: [pure: true, ids: [], name: :tpl_logic_static]}
      |> clean()
  end

  test "obv/var logic" do
    assert tpl_logic_obv() |> clean()
     ==
      %E{content:
        %E{content: [
          %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 2),
                                do: %E{content: "yay", tag: :div},
                              else: %E{content: "nope", tag: :div}},
          %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 2),
                                do: %E{content: "yay", tag: :div},
                              else: nil},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} != 2),
                                do: "yay",
                              else: "nope"},
           tag: :div},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} != 2),
                                do: "yay",
                              else: nil},
           tag: :div}
        ], tag: :_fragment
      }, tag: :_template, attrs: [ids: [num: :Obv], pure: true, name: :tpl_logic_obv]}
      |> clean()

    assert tpl_logic_var() |> clean()
     ==
      %E{content:
        %E{content: [
          %Logic.If{test: quote(do: %Logic.Var{name: "num"} == 2),
                                do: %E{content: "yay", tag: :div},
                              else: %E{content: "nope", tag: :div}},
          %Logic.If{test: quote(do: %Logic.Var{name: "num"} == 2),
                                do: %E{content: "yay", tag: :div},
                              else: nil},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Var{name: "num"} != 2),
                                do: "yay",
                              else: "nope"},
               tag: :div},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Var{name: "num"} != 2),
                                do: "yay",
                              else: nil},
               tag: :div}
        ], tag: :_fragment
      }, tag: :_template, attrs: [ids: [num: :Var], pure: false, name: :tpl_logic_var]}
      |> clean()

    assert tpl_logic_mixed([num: 2]) |> clean()
     ==
      %E{content:
        %E{content: [
          %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} == 2),
                      do: %E{content: "yay", tag: :div},
                    else: %E{content: "nope", tag: :div}},
          %Logic.If{test: quote(do: %Logic.Var{name: "vv"} == 2),
                      do: %E{content: "yay", tag: :div},
                    else: %E{content: "nope", tag: :div}},
          %E{content: "yay", tag: :div},

          %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} == 2),
                      do: %E{content: "yay", tag: :div},
                    else: nil},
          %Logic.If{test: quote(do: %Logic.Var{name: "vv"} == 2),
                      do: %E{content: "yay", tag: :div},
                    else: nil},
          %E{content: "yay", tag: :div},

          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} != 2),
                                do: "yay",
                              else: "nope"},
           tag: :div},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Var{name: "vv"} != 2),
                                do: "yay",
                              else: "nope"},
           tag: :div},
          %E{content: "nope", tag: :div},

          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Obv{name: "oo"} != 2),
                                do: "yay",
                              else: nil},
           tag: :div},
          %E{attrs: [],
           content: %Logic.If{test: quote(do: %Logic.Var{name: "vv"} != 2),
                                do: "yay",
                              else: nil},
           tag: :div},
          %E{content: nil, tag: :div}
        ], tag: :_fragment
      }, tag: :_template, attrs: [ids: [vv: :Var, oo: :Obv], pure: false, name: :tpl_logic_mixed]}
      |> clean()

    assert pnl_obv_assign() |> clean()
     ==
      %E{content:
        %E{content: [
          "num is", %Logic.Obv{name: "num"}
        ], tag: :div
      }, tag: :_panel,
        attrs: [
          ids: [num: :Obv],
          init: [num: 4],
          pure: true,
          name: :pnl_obv_assign
        ]
      } |> clean()

    assert pnl_inner_tpl() |> clean()
     ==
      %E{content:
        %E{content: %Logic.Call{name: :tpl_logic_obv, args: [:num]}, tag: :div
      }, tag: :_panel,
        attrs: [
          ids: [num: :Obv],
          init: [num: 4],
          pure: true,
          name: :pnl_inner_tpl
        ]
      } |> clean()
  end

  test "cond statements make nested if-statements" do
    # Focus
    # this work work until :attrs is converted from a kw-list into a map
    # pretty top priority, because the keys will get out of order and I want to generate tests
    # systematically to test each of the syntatic possibilites
    #
    # next, look into using the code "formatter" and see if what comes out is readable.
    # if it is, switch over, cause formatting these tests is a total pain.
    #
    # tag_ = Lens.make_lens(:tag)
    # attrs_ = Lens.make_lens(:attrs)
    # content_ = Lens.make_lens(:content)
    # name_ = Lens.make_lens(:name)
    # test_ = Lens.make_lens(:test)
    # do_ = Lens.make_lens(:do)
    # else_ = Lens.make_lens(:else)
    # ids_ = Lens.make_lens(:ids)
    # pure_ = Lens.make_lens(:pure)

    v_els =
      %E{content:
        %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 1),
                    do: %E{content: "one", tag: :div},
                  else: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 2),
                                    do: %E{content: "two", tag: :div},
                                  else: %Logic.If{test: quote(do: %Logic.Obv{name: "num"} == 3),
                                                    do: %E{content: "three", tag: :div},
                                                  else: %E{content: "nope", tag: :div}}}},
        tag: :_template, attrs: [ids: [num: :Obv], pure: true, name: nil]}
      |> Logic.handle_logic()
      |> Logic.clean_quoted()
      |> clean()

    assert tpl_logic_if()
      |> Logic.handle_logic()
      |> Logic.clean_quoted()
      |> clean() == Map.replace!(v_els, :attrs,
          Keyword.update!(v_els.attrs, :name, fn _ -> :tpl_logic_if end)
        )

    assert tpl_logic_cond()
      |> Logic.handle_logic()
      |> Logic.clean_quoted()
      |> clean() == Map.put(v_els, :attrs,
          Keyword.update!(v_els.attrs, :name, fn _ -> :tpl_logic_cond end)
        )
      # |> clean() == Focus.set(attrs_ ~> name_, v_els, :tpl_logic_if)
  end
end

# > Focus.view(address ~> locale ~> street, person)
# "Homer"
