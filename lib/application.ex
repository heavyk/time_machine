defmodule TimeMachine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    Supervisor.start_link([
      # calls TimeMachine.Templates.start_link([])
      TimeMachine.Templates,
    ], [strategy: :one_for_one, name: TimeMachine.Supervisor])
  end

  # when the application is updated
  def config_change(_changed, _new, _removed) do
    :ok
  end
end
