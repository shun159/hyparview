defmodule Hyparview.Messages.Neighbor do
  @moduledoc """
  NEIGHBOR request
  """

  alias __MODULE__
  alias Hyparview.View
  alias Hyparview.Utils
  alias Hyparview.PeerManager
  alias Hyparview.Messages.NeighborRejected
  alias Hyparview.Messages.NeighborAccepted

  defstruct priority: :low,
            sender: Node.self()

  @type t :: %Neighbor{
          priority: :low | :high,
          sender: Node.t()
        }

  @spec new(View.t()) :: t()
  def new(view) do
    %Neighbor{priority: get_priority(view), sender: Node.self()}
  end

  @doc """
  Send a neighbor message that includes the node name and priority level to a node
  that chosen from passive_view at random. the priority level may take two values:
  if it has empty active_view the priority is HIGH, priority is LOW otherwise.

      :ok = Neighbor.send!(state.view)
  """
  @spec send!(View.t()) :: :ok
  def send!(view) do
    view.passive
    |> Utils.choose_node()
    |> PeerManager.send_message(new(view))
  end

  @spec send_after(View.t(), non_neg_integer()) :: reference()
  def send_after(view, base_time) do
    after_msec = Utils.random_delay(base_time)

    view.passive
    |> Utils.choose_node()
    |> PeerManager.send_after(new(view), after_msec)
  end

  @doc """
  If node received a high priority NEIGHBOR request will always accept the request,
  even if it has to drop a random member from its active view.

  If received a low priority NEIGHBOR request it will only accept
  the request if it has a free slot in its active view.

  If the NEIGHBOR request rejected, initiator will select another node from
  its passive view and repeat the whole procedure.

      view = Neighbor.handle(neighbor, state.view)
      {:noreply, %{state | view: view}}
  """
  @spec handle(t(), View.t()) :: View.t()
  def handle(%Neighbor{priority: :low, sender: sender}, view) when sender != node() do
    if View.has_free_slot_in_active_view?(view) do
      try_add_node_to_active(sender, view)
    else
      :ok = NeighborRejected.send!(sender, view)
      view
    end
  end

  def handle(%Neighbor{sender: sender}, view) when sender != node() do
    try_add_node_to_active(sender, view)
  end

  def handle(%Neighbor{sender: sender}, view) do
    :ok = NeighborRejected.send!(sender, view)
    view
  end

  # private functions

  @spec try_add_node_to_active(Node.t(), View.t()) :: View.t()
  defp try_add_node_to_active(sender, view0) do
    case View.try_add_node_to_active(sender, view0) do
      {:ok, view} ->
        :ok = Hyparview.EventHandler.add_node(sender, view)
        :ok = NeighborAccepted.send!(sender, view)
        view

      {{:error, _reason}, view} ->
        :ok = NeighborRejected.send!(sender, view)
        view
    end
  end

  @spec get_priority(View.t()) :: :high | :low
  defp get_priority(view) do
    if Enum.empty?(view.active),
      do: :high,
      else: :low
  end
end
