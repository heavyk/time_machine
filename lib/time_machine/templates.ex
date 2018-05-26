defmodule TimeMachine.Templates do
  alias TimeMachine.Logic
  use GenServer

  @info_tab :tm_tpl_info
  @ast_tab :tm_tpl_ast

  defmacro __using__(_) do
    mod = __CALLER__.module
    case :erlang.function_exported(mod, :__info__, 1) do
      true -> nil
      _ ->
        # IO.puts "use TimeMachine.Templates #{mod}"
        Module.register_attribute(mod, :templates, accumulate: true)
        Module.register_attribute(mod, :panels, accumulate: true)
        Module.register_attribute(mod, :components, accumulate: true)
        Module.register_attribute(mod, :css, accumulate: true)
        quote do
          # @on_definition TimeMachine.Templates
          @before_compile TimeMachine.Templates
        end
    end
  end

  def __on_definition__(_env, _kind, name, args, _guards, _body) do
    IO.puts "defining: #{name}"
    case args do
      [{:\\, _, [{:var!, _, [{:assigns, _, TimeMachine.Elements}]}, []]}] ->
        # this is pretty unused right now.
        nil
      _args_ -> nil
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def templates(), do: @templates
      def panels(), do: @panels
      def components(), do: @components
      def css(), do: @css
    end
  end

  # client

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def define(mod, name, type, info) do
    :ets.insert(@info_tab, {{mod, type, :name}, name})
    :ets.insert(@info_tab, {{mod, name, :type}, type})
    :ets.insert(@info_tab, {{mod, name, :info}, info})
  end

  def insert(mod, name, assigns, ast) do
    id = Logic.call_id(name, assigns)
    :ets.insert(@ast_tab, {{mod, name, assigns, :id}, id})
    :ets.insert(@ast_tab, {{mod, id, :assigns}, {name, assigns}})
    :ets.insert(@ast_tab, {{mod, id, :ast}, ast})
    # TODO: need to do deduplication of ids...
    #       assigns which don't produce different asts should have different ids, but resolve to the same ast
    # TODO: I should probably pass everything to the template (including the vars), then in the optimisation phase get rid of the unnecessary ones
    args = Logic.enum_logic(ast, [:Obv, :Condition], :name, :type)
    calls = Logic.enum_logic(ast, :Call, :id, :count)
    # TODO: I think these should be saved together as a metadata (I believe they are always used at the same time)
    :ets.insert(@info_tab, {{mod, id, :args}, args})
    :ets.insert(@info_tab, {{mod, id, :calls}, calls})
  end

  def all_of(mod, type) do
    :ets.lookup(@info_tab, {mod, type, :name})
    |> Enum.map(fn {_, name} -> name end)
  end

  def type_of(mod, name) do
    case mod do
      nil -> nil
      _ ->
        case :ets.lookup(@info_tab, {mod, name, :type}) do
          [{_, type}] -> type
          _ -> nil
        end
    end
  end

  def get_info(mod, id) do
    case :ets.lookup(@info_tab, {mod, id, :info}) do
      [{_, info}] -> info
      _ -> nil
    end
  end

  def get_args(mod, id) do
    case :ets.lookup(@info_tab, {mod, id, :args}) do
      [{_, args}] -> args
      _ ->
        {name, assigns} = get_name_and_assigns(mod, id)
        apply(mod, name, assigns)
        get_args(mod, id)
    end
  end
  def get_args(mod, name, assigns) do
    id = Logic.call_id(name, assigns)
    get_args(mod, id)
  end

  def get_calls(mod, id) do
    case :ets.lookup(@info_tab, {mod, id, :calls}) do
      [{_, calls}] ->
        Enum.reduce(calls, [], fn {id, count}, calls ->
          get_calls(mod, id)
          |> Keyword.merge(calls)
          |> Keyword.merge([{id, count}])
        end)
      _ -> nil
    end
  end

  def get_ast(mod, id) do
    case :ets.lookup(@ast_tab, {mod, id, :ast}) do
      [{_, ast}] -> ast
      _ -> nil
    end
  end

  def get_name_and_assigns(mod, id) do
    case :ets.lookup(@ast_tab, {mod, id, :assigns}) do
      [{_, assigns}] -> assigns
      _ -> nil
    end
  end

  def get_vars(mod, id) do
    ast = get_ast(mod, id)
    vars = Logic.enum_logic(ast, [:Obv, :Condition, :Var], :name, :type)
    calls = get_calls(mod, id)
    IO.puts "get_vars: #{mod} #{id} - #{inspect vars} - #{inspect calls}"
    inner_vars = Enum.reduce(calls, vars, fn {id, _v}, vars ->
      IO.puts "inner_vars,get_vars: #{mod} #{id}"
      get_vars(mod, id)
      |> Keyword.merge(vars)
    end)
    IO.puts "inner_vars #{inspect inner_vars}"
    inner_vars
  end

  # server

  def handle_info({:define, {mod, name, type}}, state) do
    :ets.insert(@info_tab, {{mod, type, :name}, name})
    :ets.insert(@info_tab, {{mod, name, :type}, type})
    {:noreply, state}
  end
  def handle_info({:insert, {mod, name, info}}, state) do
    :ets.insert(@info_tab, {{mod, name, :info}, info})
    {:noreply, state}
  end
  def handle_info({:insert, {mod, name, assigns, ast}}, state) do
    :ets.insert(@ast_tab, {{mod, name, assigns}, ast})
    {:noreply, state}
  end

  def init(_) do
    :ets.new(@info_tab, [:set, :named_table, :public])
    :ets.new(@ast_tab, [:set, :named_table, :public])
    {:ok, %{}}
  end
end
