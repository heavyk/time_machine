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
    assert (tpl_test([val: 1234])) == %E{tag: :_template,
                                         attrs: [pure: true, ids: [], name: :tpl_test],
                                         content: %E{tag: :div,
                                                     content: "test 1234"}}
  end

  test "fragments" do
    assert tpl_one_item_frag() == %E{tag: :_template, content: %E{tag: :_fragment, content:
        %E{tag: :div, content: "test"}
      }, attrs: [pure: true, ids: [], name: :tpl_one_item_frag]}

    assert (tpl_inner_frag([num: 11])) == %E{tag: :_template, content: %E{tag: :_fragment, content: [
        %E{tag: :div, content: 1},
        %E{tag: :div, content: 1.1},
        %E{tag: :div, content: 11},
        %E{tag: :div, content: 11.1}
      ]}, attrs: [pure: true, ids: [], name: :tpl_inner_frag]}
  end

  test "components" do
    assert (foto size: 180, id: "lol", title: "an image") ==
      %E{tag: :_component, content: %E{tag: :img, attrs: [src: "/i/m/lol",
                                                          title: "an image",
                                                          alt: "an image"]},
         attrs: [pure: true, ids: [], name: :foto]}
  end

  test "static logic" do
    assert tpl_logic_static([num: 1]) == %E{content:
      %E{content: [
        %E{content: "nope", tag: :div},
        nil,
        %E{content: "yay", tag: :div},
        %E{content: "yay", tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [pure: true, ids: [], name: :tpl_logic_static]}

    assert tpl_logic_static([num: 2]) == %E{content:
      %E{content: [
        %E{content: "yay", tag: :div},
        %E{content: "yay", tag: :div},
        %E{content: "nope", tag: :div},
        %E{content: nil, tag: :div}
      ], tag: :_fragment
    }, tag: :_template, attrs: [pure: true, ids: [], name: :tpl_logic_static]}
  end

  test "obv/var logic" do
    assert Logic.clean(tpl_logic_obv()) == Logic.clean(%E{content:
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
    }, tag: :_template, attrs: [ids: [num: :Obv], pure: true, name: :tpl_logic_obv]})

    assert Logic.clean(tpl_logic_var()) == Logic.clean(%E{content:
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
    }, tag: :_template, attrs: [ids: [num: :Var], pure: false, name: :tpl_logic_var]})

    assert Logic.clean(tpl_logic_mixed([num: 2])) == Logic.clean(%E{content:
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
    }, tag: :_template, attrs: [ids: [vv: :Var, oo: :Obv], pure: false, name: :tpl_logic_mixed]})
  end
end
