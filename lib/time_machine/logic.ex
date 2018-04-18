

# platform properties such as `width`, and `height`, `dpr`, etc.
# config properties set by the loading environment
# should be thought of as "immutable", but they can change
# if any of these change, the thing will reinitialise
# they are provided as obvs, just because often times their values
# are used in calculations
defmodule TimeMachine.Logic.Ref do
  defstruct tag: :_ref,
           name: nil
end

# environmental observable
defmodule TimeMachine.Logic.Condition do
  defstruct tag: :_cod,
           name: nil
end

# environmental variable (changes in the value are not propagated in real-time)
defmodule TimeMachine.Logic.Var do
  defstruct tag: :_var,
           name: nil
end

# local to the template, real-time updating value
defmodule TimeMachine.Logic.Obv do
  defstruct tag: :_obv,
           name: nil
end

# assignment expression
defmodule TimeMachine.Logic.Assign do
  defstruct tag: :_ass,
           name: nil,
           type: nil,
          value: nil
end

# one-way bindings (set the lhs every time the rhs changes)
defmodule TimeMachine.Logic.Bind1 do
  defstruct tag: :_b1,
            lhs: nil,
            rhs: nil
end

# two-way bindings, beginning with the lhs value
defmodule TimeMachine.Logic.Bind2 do
  defstruct tag: :_b2,
            lhs: nil,
            rhs: nil
end

# event listener which saves the result of rhs into lhs
defmodule TimeMachine.Logic.Modify do
  defstruct tag: :_mod,
           name: nil,
           type: nil,
            fun: nil
end

# inline template logic
defmodule TimeMachine.Logic.If do
  defstruct tag: :_if,
           test: true,
             do: nil,
           else: nil
end

# inline template loop
defmodule TimeMachine.Logic.Loop do
  defstruct tag: :_loop,
           test: true,
             do: nil, # does this when true
           else: nil # this when test is false
end

# does do for every element in obv
defmodule TimeMachine.Logic.Each do
  defstruct tag: :_each,
            obv: nil,
             do: nil, # does this when obv truthy or length > 0
           else: nil # this when obv is falsy or length zero
end

# inline piece of js (single expression)
defmodule TimeMachine.Logic.Js do
  defstruct tag: :_js,
        content: nil
end

# content with js on both sides of it (how does this look in js ast?)
defmodule TimeMachine.Logic.JsWrap do
  defstruct tag: :__js,
            lhs: nil,
        content: nil,
            rhs: nil
end

defmodule TimeMachine.Logic do
  alias Marker.Element
  alias TimeMachine.Logic

  defstruct tag: nil, content: nil, attrs: []

  defmacro __using__(_) do
    quote do
      alias TimeMachine.Logic
    end
  end

  def clean(ast) when is_list(ast) do
    Enum.map(ast, &clean/1)
  end
  def clean(%Logic.If{tag: :_if, test: test_, do: do_, else: else_}) do
    %Logic.If{test: clean_quoted(test_), do: clean(do_), else: clean(else_)}
  end
  def clean(%Element{tag: tag_, content: content_, attrs: attrs_}) do
    %Element{tag: tag_, content: clean(content_), attrs: clean(attrs_)}
  end
  def clean(ast) do
    Macro.update_meta(ast, fn (_meta) -> [] end)
  end
  # negative emotion speaks to my misunderstanding what is rally going on
  # negative emotion also means that I have summoned more than I am allowing right now


  @doc false
  def handle_logic(block, info) do
    # perhaps this could be moved to TimeMachine.Logic
    info = Keyword.put_new(info, :ids, [])
      |> Keyword.put_new(:pure, true)
    {block, info} = Macro.traverse(block, info, fn
      # PREWALK (going in)
      { :@, meta, [{ name, _, atom }]} = expr, info when is_atom(name) and is_atom(atom) ->
        # static variable to modify how the template is rendered
        name = name |> to_string()
        # IO.puts "@#{name} ->"
        line = Keyword.get(meta, :line, 0)
        cond do
          name |> String.last() == "!" ->
            name = String.trim_trailing(name, "!") |> String.to_atom()
            expr = quote line: line do
              Marker.fetch_assign!(var!(assigns), unquote(name))
            end
            {expr, info}
          true ->
            name = String.to_atom(name)
            assign = quote line: line do
              Access.get(var!(assigns), unquote(name))
            end
            {assign, info}
        end

      expr, info ->
        # IO.puts "prewalk expr: #{inspect expr}"
        {expr, info}
      # END PREWALK
    end, fn
      # POSTWALK (coming back out)
      { sigil, _meta, [{:<<>>, _, [name]}, _]}, info when sigil in [:sigil_O, :sigil_o, :sigil_v] ->
        type = case sigil do
          :sigil_O -> :Condition
          :sigil_o -> :Obv
          :sigil_v -> :Var
        end
        expr =
          {:%, [], [{:__aliases__, [alias: false], [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}
        name = String.to_atom(name)
        ids = info[:ids]
        ids = case t = Keyword.get(ids, name) do
          nil -> Keyword.put(ids, name, type)
          ^type -> ids
          _ -> raise RuntimeError, "#{name} is a #{t}. it cannot be redefined to be a #{type} in the same template"
        end
        info = info
          |> Keyword.put(:ids, ids)
          |> Keyword.update(:pure, true, fn is_pure -> is_pure and type == :Obv end)
        {expr, info}

      { :if, _meta, [left, right]} = expr, info ->
        ids = Logic.get_ids(expr)
        cond do
          length(ids) > 0 ->
            do_ = Keyword.get(right, :do)
            else_ = Keyword.get(right, :else, nil)
            test_ = Macro.escape(left) |> Logic.clean_quoted()
            expr = quote do: %TimeMachine.Logic.If{test: unquote(test_),
                                                     do: unquote(do_),
                                                   else: unquote(else_)}
            {expr, info}
          true ->
            {expr, info}
        end

      { :=, _meta, [{:%, [], [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}, value]}, info ->
        # IO.puts "assignment: #{inspect type} #{name} = #{inspect value}"
        expr = quote do: %TimeMachine.Logic.Assign{name: unquote(name), type: unquote(type), value: unquote(value)}
        {expr, info}

      expr, info ->
        # IO.puts "postwalk expr: #{inspect expr}"
        {expr, info}
      # END postwalk
    end)
    {block, info}
  end
  def handle_logic(block) do
    {block, _info} = handle_logic(block, [])
    block
  end

  @doc "resolve aliases & remove any meta"
  def clean_quoted(ast) do
    # we cannot really use Macro.expand, because that will expand the if-statements into case statements.
    # so, instead, we do our own alias resolution
    Macro.postwalk(ast, fn
      {:%, _, [alias_, {:%{}, _, map_}]} when is_atom(alias_) ->
        {:%, [], [{:__aliases__, [alias: false], mod_list(alias_)}, {:%{}, [], map_}]}

      {:%, [], [{:__aliases__, [alias: mod_a], mod}, {:%{}, _, map_}]} ->
        cond do
          mod_a == false -> Module.concat(mod)
          is_list(mod) && mod_a == false -> Module.concat(mod)
          is_atom(mod_a) -> mod_a
          is_atom(mod) -> mod
          true -> raise "unknown alias"
        end
        |> struct(map_)

      {:__aliases__, [alias: alias_], _mod} when is_atom(alias_) and alias_ != false ->
        {:__aliases__, [alias: false], mod_list(alias_)}

      expr -> expr
      # expr -> Macro.update_meta(expr, fn (_meta) -> [] end)
    end)
    |> Macro.update_meta(fn (_meta) -> [] end)
  end

  @doc "resolve aliases & remove any meta"
  def resolve_quoted(ast) do
    # we cannot really use Macro.expand, because that will expand the if-statements into case statements.
    # so, instead, we do our own alias resolution
    Macro.postwalk(ast, fn
      {:%, [], [{:__aliases__, [alias: mod_a], mod}, {:%{}, _, map_}]} ->
        cond do
          mod_a == false -> Module.concat(mod)
          is_list(mod) && mod_a == false -> Module.concat(mod)
          is_atom(mod_a) -> mod_a
          is_atom(mod) -> mod
          true -> raise "unknown alias"
        end
        |> struct(map_)

      {:__aliases__, [alias: alias_], _mod} when is_atom(alias_) and alias_ != false ->
        {:__aliases__, [alias: false], mod_list(alias_)}

      # expr -> expr
      expr -> Macro.update_meta(expr, fn (_meta) -> [] end)
    end)
    # |> Macro.update_meta(fn (_meta) -> [] end)
  end

  @doc "traverse ast looking for TimeMachine.Logic.* like :atom or [:atom]"
  def get_ids(block, like \\ nil) do
    {_, ids} = Macro.postwalk(block, [], fn
      {:__aliases__, [alias: alias_], _mod}, ids when is_atom(alias_) and alias_ != false -> # is this necessary?
        {{:__aliases__, [alias: false], mod_list(alias_)}, ids}

      {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, _, [name: name]}]} = expr, ids ->
        ids = cond do
          (is_atom(like) && type == like) ||
          (is_list(like) && type in like) ||
          (like == nil) -> Keyword.put(ids, String.to_atom(name), type)
          true -> ids
        end
        {expr, ids}

      {:=, _, [lhs, rhs]} = expr, ids ->
        IO.puts "assignment: #{inspect lhs} #{inspect rhs}"
        {expr, ids}

      expr, ids ->
        {expr, ids}
    end)
    ids
  end

  defp mod_list(alias_) do
    Module.split(alias_) |> Enum.map(&String.to_atom/1)
  end
end
