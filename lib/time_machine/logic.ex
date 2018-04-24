

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

# assignment expression: initialisation value of an obv/var in a scope
defmodule TimeMachine.Logic.Assign do
  defstruct tag: :_ass,
            obv: nil,
          value: nil
end

# permutation (a real-time obv which is a transformation on other values)
defmodule TimeMachine.Logic.Permutation do
  defstruct tag: :_perm,
            obv: nil,
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

# event listener which saves the result of `fun` into `obv`
defmodule TimeMachine.Logic.Modify do
  defstruct tag: :_T,
            obv: nil,
            fun: nil
end

# double event listener which sets the result of `fun` into `set`
defmodule TimeMachine.Logic.Press do
  defstruct tag: :_P,
            obv: nil,
            fun: nil
end

# transform/compute `obv` obv(s) (can be a list) with `fun` function and store value into returned obv
defmodule TimeMachine.Logic.Transform do
  defstruct tag: :_t,
            obv: nil,
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
  alias TimeMachine.Logic

  defstruct tag: nil, content: nil, attrs: []

  defmacro __using__(_) do
    quote do
      alias TimeMachine.Logic
    end
  end

  # negative emotion speaks to my misunderstanding what is rally going on
  # negative emotion also means that I have summoned more than I am allowing right now
  # negative emotion means I am holding myself in perfect vibrational harmony with something I do not want


  @doc false
  def handle_logic(block, info) do
    info = Keyword.put_new(info, :ids, [])
      |> Keyword.put_new(:pure, true)
    {block, info} = Macro.traverse(block, info, fn
      # PREWALK (going in)
      { :@, meta, [{ name, _, atom }]} = expr, info when is_atom(name) and is_atom(atom) ->
        # first inline server-side values passed to the template (assigns)
        name = name |> to_string()
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

      expr, info ->
        # IO.puts "prewalk expr: #{inspect expr}"
        {expr, info}
      # END PREWALK
    end, fn
      # POSTWALK (coming back out)
      { op, _meta, fun } = expr, info when op in [:+, :-, :*, :/] -> # for %, a guard needs to skip structs
        ids = get_ids(expr, [:Obv, :Condition])
        len = length(ids)
        obv = Enum.map(ids, fn {name, type} ->
          type = Module.concat([:TimeMachine, :Logic, type])
          quote do: %unquote(type){name: unquote(name)}
        end)
        # IO.puts "op: #{op} #{len} #{inspect ids} #{inspect fun}"
        expr = cond do
          len > 1 ->
            fun = do_fun(expr, ids)
            quote do: %Logic.Transform{obv: unquote(obv), fun: unquote(fun)}

          len == 1 ->
            # obv = quote do: %unquote(type){name: unquote(name)}
            obv = hd(obv)
            fun = do_fun(expr, ids)
            quote do: %Logic.Transform{obv: unquote(obv), fun: unquote(fun)}

          true -> expr
        end
        {expr, info}

      { :cond, _meta, [_lhs, _rhs]} = expr, info ->
        raise RuntimeError, "cond not yet implemented. it'll be a chain of if-statements though"
        {expr, info}

      { :if, _meta, [lhs, rhs]} = expr, info ->
        ids = Logic.get_ids(expr)
        cond do
          length(ids) > 0 ->
            do_ = Keyword.get(rhs, :do)
            else_ = Keyword.get(rhs, :else, nil)
            test_ = Macro.escape(lhs) |> Logic.clean_quoted()
            expr = quote do: %TimeMachine.Logic.If{test: unquote(test_),
                                                     do: unquote(do_),
                                                   else: unquote(else_)}
            {expr, info}
          true ->
            {expr, info}
        end

      { op, _meta, [{:%, [], [{:__aliases__, _, [:TimeMachine, :Logic, type] = mod}, {:%{}, [], [name: name]}]}, value]}, info when op in [:=, :<~] ->
        # IO.puts "assignment: #{inspect type} #{name} = #{inspect value}"
        # TODO: verify that <~ value is in fact a transformation or some sort of permutation
        # IO.puts "assign: #{op} #{type} #{name} #{inspect value}"
        literal = is_literal(value)
        cond do
          op == :<~ and literal ->
            raise RuntimeError, "assigning literal '#{value}' into #{name} - instead, use '=' for assignment"
          op == := and not literal ->
            raise RuntimeError, "cannot assign value '#{inspect value}' because it is not a literal"
          op == :<~ and type != :Obv ->
            raise RuntimeError, "#{name} should be an Obv - you cannot store a permutation in anything other than an Obv"
          # op == :<~ and not is_transform(value) ->
          #   raise RuntimeError, "#{name} should be a transformation"
          true -> nil
        end
        type = Module.concat(mod)
        expr = quote do: %Logic.Assign{obv: %unquote(type){name: unquote(name)}, value: unquote(value)}
        name = String.to_atom(name)
        defines = info[:defines]
        defines = cond do
          is_list(defines) ->
            case t = Keyword.get(defines, name) do
              nil -> Keyword.put(defines, name, type)
              ^type -> defines
              _ -> raise RuntimeError, "#{name} is a #{t}. it cannot be redefined to be a #{type} in the same template"
            end
          true ->
            raise RuntimeError, "no good! you cannot assign things in a template. use a panel to create a new 'environment' in which you can define things"
        end
        info = Keyword.put(info, :defines, defines)
        {expr, info}

      {fun, _meta, args} = expr, info when is_atom(fun) and is_list(args) ->
        # IO.puts "function? #{fun}"
        # lookup in ets the atom to see if it exists as a template
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
      { sigil, _meta, [{:<<>>, _, [_name]}, _]}, _ when sigil in [:sigil_O, :sigil_o, :sigil_v] ->
        raise RuntimeError, "(internal badness): horray! you have found a bug! please report this\n" <>
            "for whatever reason you are looking for ids on unhandled logic (run Logic.handle_logic/2 first)"

      {:__aliases__, [alias: alias_], _mod}, ids when is_atom(alias_) and alias_ != false -> # is this necessary?
        IO.puts "convert alias: #{alias_}"
        {{:__aliases__, [alias: false], mod_list(alias_)}, ids}

      {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, _, [name: name]}]} = expr, ids ->
        ids = cond do
          (is_atom(like) && type == like) ||
          (is_list(like) && type in like) ||
          (like == nil) -> Keyword.put(ids, String.to_atom(name), type)
          true -> ids
        end
        {expr, ids}

      expr, ids ->
        {expr, ids}
    end)
    ids
  end

  defp mod_list(alias_) do
    Module.split(alias_) |> Enum.map(&String.to_atom/1)
  end

  defp do_fun(block, ids) do
    Macro.postwalk(block, fn
      {:__aliases__, [alias: alias_], _mod} when is_atom(alias_) and alias_ != false -> # is this necessary?
        {:__aliases__, [alias: false], mod_list(alias_)}

      {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, _type]}, {:%{}, _, [name: name]}]} = expr ->
        id = String.to_atom(name)
        cond do
          Keyword.has_key?(ids, id) -> id
          true -> expr
        end

      expr -> expr
    end)
    |> Macro.escape()
  end

  defp is_literal(v) when is_list(v), do: Enum.all?(v, &is_literal/1)
  defp is_literal(v) when is_binary(v) or is_number(v) or is_atom(v) or is_boolean(v) or is_nil(v), do: true
  defp is_literal(_), do: false
end
