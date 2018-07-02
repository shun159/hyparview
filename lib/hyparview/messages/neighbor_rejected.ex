defmodule Hyparview.Messages.NeighborRejected do
  @moduledoc """
  NEIGHBOR REJECTED message
  """

  alias __MODULE__
  alias Hyparview.Messages.Neighbor
  alias Hyparview.View
  alias Hyparview.PeerManager
  alias Hyparview.Utils

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
  def handle(%NeighborRejected{view: remote_view, sender: sender}, view0) do
    view = View.trim_and_add_to_passive(view0, remote_view.passive)

    after_msec = Utils.random_delay(60_000)

    _tref =
      view.passive
      |> MapSet.delete(sender)
      |> Utils.choose_node()
      |> PeerManager.send_after(Neighbor.new(view), after_msec)

    view
  end
end
