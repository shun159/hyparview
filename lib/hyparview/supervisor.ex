defmodule Hyparview.Supervisor do
  @moduledoc false

  use Supervisor

  @membership %{
    id: Hyparview.Membership,
    start: {Hyparview.Membership, :start_link, []},
    type: :worker
  }

  @children [
    @membership
  ]

  @sup_flags [
    strategy: :one_for_all,
    max_restarts: 5,
    max_seconds: 10
  ]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, @sup_flags)
  end
end
