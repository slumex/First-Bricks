defmodule FirstBricks.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        FirstBricks.Store,
        {Phoenix.PubSub, name: FirstBricks.PubSub},
        FirstBricksWeb.Endpoint
      ],
      strategy: :one_for_one,
      name: FirstBricks.Supervisor
    )
  end
end
