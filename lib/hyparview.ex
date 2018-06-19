defmodule Hyparview do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Hyparview.EventHandler, []),
      worker(Hyparview.NodeMonitor, []),
      worker(Hyparview.PeerManager, [])
    ]

    opts = [strategy: :one_for_one, name: Hyparview.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
