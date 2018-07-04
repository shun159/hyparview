defmodule Hyparview.Messages.JoinAccepted do
  @moduledoc """
  A Message for JOIN accepted
  """

  alias __MODULE__
  alias Hyparview.View
  alias Hyparview.Messages.Join
  alias Hyparview.PeerManager

  defstruct sender: Node.self(),
            view: %View{}

  @type t :: %JoinAccepted{
          sender: Node.t(),
          view: View.t()
        }

  @spec new(View.t()) :: t()
  def new(view) do
    %JoinAccepted{sender: Node.self(), view: view}
  end

  @doc """
  Send to Join Accepted message to Join sender

      :ok = JoinAccepted.send!(join, view.state)
  """
  @spec send!(Join.t(), View.t()) :: :ok
  def send!(%Join{sender: sender}, view), do: PeerManager.send_message(sender, new(view))

  @doc """
  Handler function for JoinAccepted received node.
  If the Join request accepted, Join receiver send back a JoinAccepted includes
  its active view to the Join sender. When the JoinAccepted received,
  Join sender merge the active_view into its passive_view.
  Consequently, the probability of connectivity of nodes of its passive_view gets higher.

      view = JoinAccepted.handle(join_accepted, state.view)
      {:noreply, %{state | view: view}}
  """
  @spec handle(t(), View.t()) :: View.t()
  def handle(%JoinAccepted{sender: sender, view: remote_view}, view0) do
    case View.try_add_node_to_active(sender, view0) do
      {:ok, view1} ->
        view = View.trim_and_add_to_passive(view1, remote_view.passive)
        _ = Hyparview.EventHandler.add_node(sender, view)
        view

      {{:error, :failed_to_connect}, view} ->
        view
    end
  end
end
