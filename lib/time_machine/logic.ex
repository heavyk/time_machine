

defmodule TimeMachine.Logic.If do
  defstruct tag: :_if, test: true, do: nil, else: nil
end

defmodule TimeMachine.Logic.Obv do
  defstruct tag: :_obv, name: nil
end

defmodule TimeMachine.Logic.Var do
  defstruct tag: :_var, name: nil
end

defmodule TimeMachine.Logic.Ref do
  defstruct tag: :_ref, name: nil
end

defmodule TimeMachine.Logic.Condition do
  defstruct tag: :_cod, name: nil
end

# inline piece of js
defmodule TimeMachine.Logic.Js do
  defstruct tag: :_js, content: nil
end

# wrap around piece of js"
# TODO: finish me up.
defmodule TimeMachine.Logic.JsWrap do
  defstruct tag: :__js, left: nil, right: nil
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
  # negative emotion means I am misunderstanding what is rally happening

  def clean_quoted(ast) do
    # this is kind of an annoying case because we cannot really use Macro.expand,
    # because that will expand the if-statements into case statements.
    #
    # so, instead, we have to do our own alias resolution
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

      # {:__aliases__, [alias: alias_], mod} when is_atom(alias_) and alias_ != false ->
      #   mod = Module.split(alias_) |> Enum.map(&String.to_atom/1)
      #   IO.puts "unalias: #{inspect alias_} -> #{inspect mod}"
      #   {:__aliases__, [alias: false], mod}

      expr -> expr
    end)
    |> Macro.update_meta(fn (_meta) -> [] end)
  end
  # def clean_quoted({:__aliases__, [alias: alias_], mod}) when is_atom(alias_) do
  #   {:__aliases__, [alias: false], Module.split(alias_)}
  # end
  def clean(ast) do
    ast
    |> Macro.update_meta(fn (_meta) -> [] end)
    # |> Macro.expand(__ENV__)
  end
end