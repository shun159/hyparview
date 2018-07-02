defmodule Hyparview do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # _ = :dbg.tracer()
    # _ = :dbg.p(:all, :c)
    # _ = :dbg.tp(Hyparview.PeerManager, :handle_event, :x)

    children = [
      worker(Hyparview.NodeMonitor, []),
      worker(Hyparview.EventHandler, []),
      worker(Hyparview.PeerManager, [])
    ]

    opts = [strategy: :rest_for_one, name: Hyparview.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
