

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

# call to a template (name), with (assigns \\ [])
defmodule TimeMachine.Logic.Call do
  defstruct tag: :_call,
            mod: nil,
             id: nil
end

# environmental observable
defmodule TimeMachine.Logic.Condition do
  defstruct tag: :_cdn,
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

# one-way bindings (set the lhs every time the rhs changes), beginning with the rhs value
defmodule TimeMachine.Logic.Bind1 do
  defstruct tag: :_b1,
            lhs: nil,
            rhs: nil
end

# two-way bindings, beginning with the rhs value
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

# up/down event listener which sets the result of `fun` into `set`
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

  defmacro __using__(_) do
    quote do
      alias TimeMachine.Logic
    end
  end

  @lib [:h,:t,:c,:v]
  def lib_fns(), do: @lib

  # negative emotion speaks to my misunderstanding what is rally going on
  # negative emotion also means that I have summoned more than I am allowing right now
  # negative emotion means I am holding myself in perfect vibrational harmony with something I do not want

  @doc false
  def handle_logic(block, info) do
    # unused syntax possibilities: <|>, ???

    mod = Keyword.get(info, :module)
    _name = Keyword.get(info, :name)
    info = Keyword.put_new(info, :ids, [])
      |> Keyword.put_new(:pure, true)

    # TODO: the `pure` attribute really means that there are no Conditions in the logic.
    # TODO: depending on the way the scopes are laid out, only pass the obvs necessary.
    #       for now, I think I should just render them by default as pure, (eg. pass all necessary obvs)
    #       additionally, to simplify the Condition representation, just pull them all right out of `C`
    #       eg. lala = v(C['my_condition'])

    # IO.puts "handle logic: #{mod}.#{name}"
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

      { sigil, meta, [{:<<>>, _, [name]}, _]}, info when sigil in [:sigil_c, :sigil_o, :sigil_v] ->
        type = case sigil do
          :sigil_c -> :Condition
          :sigil_o -> :Obv
          :sigil_v -> :Var
        end
        expr =
          {:%, [], [{:__aliases__, [alias: false], [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}
        name = String.to_atom(name)
        cond do
          name in @lib -> logic_error meta, info, {"for now, the names #{inspect @lib} are reserved.", "use a different name :)"}
          true -> nil
        end
        ids = info[:ids]
        ids = case t = Keyword.get(ids, name) do
          nil -> Keyword.put(ids, name, type)
          ^type -> ids
          _ -> logic_error meta, info, {"`#{name}` is already a `#{t}`.", "it cannot be redefined to be a `#{type}` in the same template"}
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
        ids = enum_logic(expr, [:Obv, :Condition])
        len = length(ids)
        obv = Enum.map(ids, fn {name, type} ->
          type = logic_module(type)
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

      { :cond, meta, [[do: clauses]]} = expr, info ->
        # TODO: this is incorrect if the tests are statically compared, and don't contain any logic (eg. no ~o(...) in the condition)
        #       so, after reducing, if none of the conditions are dynamic, expr should be returned, so the cond statement is evaluated server-side
        #       (bonus points: if only some of the tests are dynamic, split the cond statement into two and evaluate the server-side expression first)
        ids = Enum.reduce(clauses, [], fn
          {:->, _, [cases, _do]}, ids ->
            enum_logic(cases) |> Keyword.merge(ids)

          _expr, ids -> ids
        end)
        case length(ids) do
          0 -> {expr, info} # statements without obvs are not transformed and evaluated normally (sorta, see above)
          _ ->
            starter = quote do: %Logic.If{test: nil, do: nil, else: nil}
            clauses = :lists.reverse(clauses)
            expr = Enum.reduce(clauses, starter, fn
              {:->, _, [cases, do__]}, {:%, _, [_, {_, _, [test: test_, do: do_, else: _else_]}]} = prev ->
                test__ = case cases |> hd() do
                  {op, _meta, _} = t when op in [:==, :!=, :===, :!==, :<, :<=, :>, :>=] -> t
                  b when is_boolean(b) -> b
                  {:when, _, _} -> logic_error meta, info, {"guard clauses are not yet supported", "you're probably doing something wrong ;)"}
                  c -> logic_error meta, info, {"unknown condition: #{inspect c}", "..."}
                end |> Macro.escape()

                # TODO: do a check to be sure the "true" statement does exist, and that it is in fact the last statement
                else__ = case test__ do
                  true -> nil
                  _ ->
                    # if the previous statement is: if(true) { do_ } - this removes the if-statement (cause it's alwaays true)
                    # someday, this can be removed, as a dead-code removal tool will optimise any always true/false statements.
                    case test_ do
                      true -> do_
                      _ -> prev
                    end
                end

                quote do: %Logic.If{test: unquote(test__), do: unquote(do__), else: unquote(else__)}

              expr, acc -> raise RuntimeError, "(internal badness): horray! you have found a bug! please report this\n" <>
                  "for whatever reason you have made an irregular cond statement that time_machine does not understand.\n" <>
                  "\n  expression: #{inspect expr}" <>
                  "\n  acc: #{inspect acc}"
            end)

            {expr, info}
        end

        # sidbar: I do not understand why the elixir code:
        #
        # if lala == 11, do: "yay", else: "no"
        #
        # turns into:
        #
        # case(lala == 11) do
        #   x when x in [false, nil] -> "no"
        #   _ -> "yay"
        # end
        #
        # instead of:
        #
        # cond do
        #   lala == 11 -> "yay"
        #   true -> "no"
        # end
        #
        # IMO, the cond statement seems quite a bit more straight forward. is it slower or something?
        # there's no way the Kernel.in() guard clause is any faster.

      { :case, meta, _ } = _expr, info ->
        logic_error meta, info, {"case statements are not (yet) transformed to js.", "use a cond statement for now"}

      { :if, _meta, [lhs, rhs]} = expr, info ->
        ids = enum_logic(lhs)
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

      # = <- <~ <~>
      { op, meta, [{:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, [], [name: name]}]}, quoted_value]}, info when op in [:=, :<-, :<~, :<~>] ->
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
        # `[[obv]] <~> [[obv]]` two-way binding between obvs (beginning with the rhs value)
        #   - neither side can be anything other than [[obv]]
        #   - must be found before the last line of a template
        #   - cannot be conditionally assigned (this restriction can potentially be relaxed - as could be otherwise)
        #
        # for finding out the last expression, it may be helpful to use Module.eval_quoted(info[:module], expr, info)
        init = info[:init]
        ids = info[:ids]
        value = case try_eval(quoted_value) do
          :error -> quoted_value
          v -> Macro.escape(v)
        end
        literal = is_literal(value)
        cond do
          op == :<~ and literal ->
            logic_error meta, info, {"assigning literal '#{value}' into #{name}", "instead, use '=' for assignment"}
          op == := and not literal ->
            logic_error meta, info, {"'#{inspect value}' is not literal", "try using <~"}
          op == :<~ and type != :Obv ->
            logic_error meta, info, {"a transformation must be stored into an Obv", "try converting #{name} into an Obv"}
          op == :<~ and type_of(value) != :Transform and type_of(value) != :Obv ->
            logic_error meta, info, {"cannot store a #{type_of(value)} as a transformation", "??? #{inspect value}"}
          true -> nil
        end
        mod = logic_module(type)
        expr = cond do
          op == := ->
            quote do: %Logic.Assign{obv: %unquote(mod){name: unquote(name)}, value: unquote(value)}
          op == :<~ ->
            case type_of(value) do
              :Obv -> quote do: %Logic.Bind1{lhs: %unquote(mod){name: unquote(name)}, rhs: unquote(value)}
              :Transform -> value
            end
          op == :<- and type_of(value) == :Transform ->
            transform = try_eval(value)
            obv = Map.get(transform, :obv)
            fun = Map.get(transform, :fun)
            quote do: %Logic.Modify{obv: unquote(obv), fun: unquote(fun)}
          op == :<~> and type_of(value) == :Obv ->
            quote do: %Logic.Bind2{lhs: %unquote(mod){name: unquote(name)}, rhs: unquote(value)}
          true ->
            logic_error meta, info, {"UNKNOWN: dunno what to do with this:\n    ~o(#{name}) #{op} #{Macro.to_string value}", "\n    #{inspect value}"}
        end
        name = String.to_atom(name)
        info = cond do
          op == :<- -> info # doesn't define anything new
          is_list(init) ->
            # if init is a list, the container can initialise values
            init = case init_val = Keyword.get(init, name) do
              nil -> Keyword.put(init, name, value)
              _ -> logic_error meta, info, {"#{name} is already initialised to #{inspect init_val}.", "you cannot also initialise it to be #{inspect value} in the same template"}
            end
            ids = case t = Keyword.get(ids, name) do
              nil -> Keyword.put(ids, name, type)
              ^type -> ids
              _ -> logic_error meta, info, {"#{name} is already a #{t}. it cannot be redefined to be a #{type} in the same template", "TODO: suggestion"}
            end
            info
            |> Keyword.put(:init, init)
            |> Keyword.put(:ids, ids)
          true -> logic_error meta, info, :cannot_define
        end
        # IO.puts "expr: #{inspect expr}\n"
        expr = Macro.escape(expr)
        {expr, info}

      # this cannot work because handle_logic is performed in the template macro when the template is defined.
      # so, that means there is no list of templates to be found anywhere.
      # that means that depending on the context when I call the function, (eg. from within a template)
      # I should return the bytecode or a Call{}
      # ....
      {fun, _meta, assigns} = expr, info when is_atom(fun) and is_list(assigns) ->
        # TODO: improve the speed of this. seems like it's gonna get hit for every operator
        case TimeMachine.Templates.type_of(mod, fun) do
          :template ->
            # then, make a js call here with the appropriate obvs passed to it (depending on how pure it is)
            # then, when templates are only called once, they can be inlined as well.
            id = call_id(fun, assigns)
            calls = Keyword.get(info, :calls, [])
              |> Keyword.merge([{id, 1}], fn _k, v1, v2 -> v1 + v2 end)
            info = Keyword.put(info, :calls, calls)
            expr = quote do: %Logic.Call{mod: unquote(mod), id: unquote(id)}
            {expr, info}

          _ -> {expr, info}
        end

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
          is_list(mod) and mod_a == false -> Module.concat(mod)
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

  @doc "traverse ast looking for TimeMachine.Logic.* like :atom or [:atom]"
  def enum_logic(block, like \\ nil, field \\ :name, value \\ :type)
  def enum_logic(%mod{} = expr, like, field, value) when is_atom(mod) do
    enum_logic({:%{}, [], Map.to_list(expr)}, like, field, value)
  end
  def enum_logic(block, like, field, value) do
    set_ids = fn ids, type, val_ ->
      cond do
        (is_atom(like) and type == like) or
        (is_list(like) and type in like) or
        (like == nil) ->
          key = as_atom(val_)
          val = case value do
            :type -> type
            :count -> Keyword.get(ids, key, 0) + 1
            value -> value == val_ or Keyword.get(ids, key)
          end
          Keyword.put(ids, key, val)
        true -> ids
      end
    end

    {_, ids} = Macro.traverse(block, [], fn
      %mod{} = expr, ids when is_atom(mod) ->
        expr = {:%{}, [], Map.to_list(expr)}
        {expr, ids}

      expr, ids ->
        {expr, ids}

    end, fn
      {:%{}, _, [{:__struct__, mod} | _] = vals} = expr, ids when is_atom(mod) ->
        type = Module.split(mod) |> List.last() |> String.to_atom()
        val = Keyword.get(vals, field)
        ids = set_ids.(ids, type, val)
        {expr, ids}

      {:__aliases__, [alias: alias_], _mod}, ids when is_atom(alias_) and alias_ != false ->
        {{:__aliases__, [alias: false], mod_list(alias_)}, ids}

      {:%, _, [{:__aliases__, _, [:TimeMachine, :Logic, type]}, {:%{}, _, vals}]} = expr, ids ->
        val = Keyword.get(vals, field)
        ids = set_ids.(ids, type, val)
        {expr, ids}

      { sigil, _, _}, _ when sigil in [:sigil_O, :sigil_o, :sigil_v, :sigil_c] ->
        internal_badness "for whatever reason you are looking for ids on unhandled logic (run Logic.handle_logic/2 first)"

      expr, ids ->
        {expr, ids}
    end)
    ids
  end

  def call_id(name, assigns) when is_atom(name) do
    Atom.to_string(name) |> call_id(assigns)
  end
  def call_id(name, assigns) when is_binary(name) do
    # TODO: kw order shouldn't make a difference, so maybe convert to map??
    String.to_atom(name <> "_" <> Integer.to_string(:erlang.phash2(Enum.into(assigns, %{}))))
  end

  defp mod_list(alias_) do
    Module.split(alias_) |> Enum.map(&String.to_atom/1)
  end

  defp logic_module(mod) when is_atom(mod) do
    Module.concat([:TimeMachine, :Logic, mod])
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

  defp try_eval(quoted_value) do
    env = __ENV__
    try do
      eval_result = quoted_value
      |> Macro.expand_once(env)
      |> Code.eval_quoted([], env)
      case eval_result do
        {eval_value, []} -> eval_value
        {_value, _vars} -> :error
      end
    rescue
      _ -> :error
    catch
      _ -> :error
    end
  end

  defp logic_error(meta, info, err) do
    raise LogicError, Keyword.merge(info, meta) |> Keyword.put(:err, err)
  end
  defp internal_badness(meta \\ [], err) do
    raise InternalBadnessError, Keyword.put(meta, :err, err)
  end

  def type_of(%mod{}) when is_atom(mod), do: Module.split(mod) |> List.last() |> String.to_atom()
  def type_of({:%{}, _, [{:__struct__, mod} | _]}) when is_atom(mod), do: Module.split(mod) |> List.last() |> String.to_atom()
  def type_of({:%, _, [{:__aliases__, _, mod}, _]}) when is_list(mod), do: List.last(mod)
  def type_of(_), do: false

  def as_atom(s) when is_binary(s), do: String.to_atom(s)
  def as_atom(s) when is_atom(s), do: s

  defp is_literal(v) when is_list(v), do: Enum.all?(v, &is_literal/1)
  defp is_literal(v) when is_binary(v) or is_number(v) or is_atom(v) or is_boolean(v) or is_nil(v), do: true
  defp is_literal(_), do: false
end

# placemat process
defmodule TimeMachine.Logic.Quote do
  # TODO: make lot's of generic builder functions like this one and get rid of a lot the quotes
  def value(name, type \\ :Obv) do
    full_type = logic_module(type)
    quote do: %unquote(full_type){name: unquote(name)}
  end

  def if(test, do_, else_) do
    case is_literal(test) do
      false -> quote do: %Logic.If{test: unquote(test), do: unquote(do_), else: unquote(else_)}
      true ->
        cond do
          !!test -> quote do: unquote(do_)
          true -> quote do: unquote(else_)
        end
    end
  end

  defp logic_module(mod) when is_atom(mod) do
    Module.concat([:TimeMachine, :Logic, mod])
  end

  defp is_literal(v) when is_list(v), do: Enum.all?(v, &is_literal/1)
  defp is_literal(v) when is_binary(v) or is_number(v) or is_atom(v) or is_boolean(v) or is_nil(v), do: true
  defp is_literal(_), do: false
end
