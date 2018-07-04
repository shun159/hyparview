defmodule Hyparview.Messages.NeighborRejected do
  @moduledoc """
  NEIGHBOR REJECTED message
  """

  alias __MODULE__
  alias Hyparview.Messages.Neighbor
  alias Hyparview.View
  alias Hyparview.PeerManager
  alias Hyparview.Utils
  alias Hyparview.Config

  defstruct sender: Node.self(),
            view: %View{}

  @type t :: %NeighborRejected{
          sender: Node.t(),
          view: View.t()
        }

  @spec new(View.t()) :: t()
  def new(view) do
    %NeighborRejected{sender: Node.self(), view: view}
  end

  @spec send!(Node.t(), View.t()) :: :ok
  def send!(sender, view), do: :ok = PeerManager.send_message(sender, new(view))

  @doc """
     view = NeighborRejected.handle(neighbor_rejected, state.view)
     {:noreply, %{state | view: view}}
  """
  @spec handle(t(), View.t()) :: View.t()
  def handle(%NeighborRejected{view: %View{passive: r_passive}, sender: sender}, view0) do
    after_msec =
      Config.neighbor_interval()
      |> Utils.random_delay()

    view = View.trim_and_add_to_passive(view0, r_passive)
    passive = MapSet.delete(view.passive, sender)
    tmp_view = %{view | passive: passive}

    _tref = Neighbor.send_after(tmp_view, after_msec)

    view
  end
end
