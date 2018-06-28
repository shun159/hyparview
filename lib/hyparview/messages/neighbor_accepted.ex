defmodule Hyparview.Messages.NeighborAccepted do
  @moduledoc """
  NEIGHBOR ACCEPTED message
  """

  alias __MODULE__
  alias Hyparview.View
  alias Hyparview.PeerManager

  defstruct sender: Node.self(),
            view: %View{}

  @type t :: %NeighborAccepted{
          sender: Node.t(),
          view: View.t()
        }

  @spec new(View.t()) :: t()
  def new(view) do
    %NeighborAccepted{sender: Node.self(), view: view}
  end

  @spec send!(Node.t(), View.t()) :: :ok
  def send!(sender, view), do: :ok = PeerManager.send_message(sender, new(view))

  @doc """
  If the node receives NeighborAccepted message, insert the sender into its active view.

     view = NeighborAccepted.handle(neighbor_accepted, state.view)
     {:noreply, %{state | view: view}}
  """
  @spec handle(t(), View.t()) :: View.t()
  def handle(%NeighborAccepted{sender: sender}, view0) do
    :ok = Hyparview.EventHandler.add_node(sender, view0)

    view0
    |> View.move_passive_to_active(sender)
  end
end
