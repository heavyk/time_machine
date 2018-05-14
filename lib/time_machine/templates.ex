defmodule TimeMachine.Templates do
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
          @on_definition TimeMachine.Templates
          @before_compile TimeMachine.Templates
        end
    end
  end

  def __on_definition__(_env, _kind, _name, args, _guards, _body) do
    case args do
      [{:\\, _, [{:var!, _, [{:assigns, _, TimeMachine.Elements}]}, []]}] ->
        # no longer necessary. it's done in the macro
        # Module.put_attribute(env.module, :templates, name)
        nil
      _args_ -> nil
    end
  end

  defmacro __before_compile__(_env) do
    # IO.puts "before compile #{env.module}"
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

  def insert(mod, name, assigns, js_ast) do
    # Process.send(self(), {:insert, {mod, name, assigns, js_ast}}, [])
    :ets.insert(@ast_tab, {{mod, name, assigns}, js_ast})
  end

  def all_of(mod, type) do
    :ets.lookup(@info_tab, {mod, type, :name})
    |> Enum.map(fn {_, name} -> name end)
  end

  def type_of(mod, name) do
    case :ets.lookup(@info_tab, {mod, name, :type}) do
      [{_, type}] -> type
      _ -> nil
    end
  end

  def get_info(mod, name) do
    case :ets.lookup(@info_tab, {mod, name, :info}) do
      [{_, info}] -> info
      _ -> nil
    end
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
  def handle_info({:insert, {mod, name, assigns, js_ast}}, state) do
    :ets.insert(@ast_tab, {{mod, name, assigns}, js_ast})
    {:noreply, state}
  end

  def init(_) do
    :ets.new(@info_tab, [:set, :named_table, :public])
    :ets.new(@ast_tab, [:set, :named_table, :public])
    {:ok, %{}}
  end
end
