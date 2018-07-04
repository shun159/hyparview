defmodule Hyparview.Messages.Join do
  @moduledoc """
  JOIN request abstraction module
  """

  import Logger, only: [debug: 1]

  alias __MODULE__
  alias Hyparview.Utils
  alias Hyparview.View
  alias Hyparview.PeerManager
  alias Hyparview.Messages.ForwardJoin
  alias Hyparview.Messages.JoinAccepted
  alias Hyparview.Messages.JoinFailed

  defstruct sender: Node.self()

  @type t :: %Join{sender: Node.t()}

  @spec new() :: t()
  def new, do: %Join{sender: Node.self()}

  @doc """
  Asynchronously send a JOIN message to a chosen node at random from contact node.

     :ok = Join.send(Join.new(), state.view)
  """
  @spec send!(View.t() | Node.t()) :: :ok
  def send!(node) when is_atom(node), do: :ok = PeerManager.send_message(node, new())

  def send!(%View{passive: passive}) do
    passive
    |> Utils.choose_node()
    |> send!()
  end

  @spec send_after(View.t(), non_neg_integer()) :: reference()
  def send_after(%View{passive: passive}, after_msec) do
    passive
    |> Utils.choose_node()
    |> PeerManager.send_after(new(), after_msec)
  end

  @doc """
  Handler function for JOIN request receiver

  1. If the receiver has free slot in its active view,
     accept the JOIN and propagates FORWARDJOIN message to all node in its active view.
     and then add the JOIN sender to its active view and send back JOINACCEPTED to the sender.

  2. other than those above, receiver replies a JOINFAILED message.

      view = Join.handle(join, state.view)
      {:noreply, %{state | view: view}}
  """
  @spec handle(t(), view0 :: View.t()) :: View.t()
  def handle(%Join{sender: sender} = join, view0) when sender != node() do
    if View.has_free_slot_in_active_view?(view0) do
      :ok = maybe_send_forward_join(view0, join)
      {_, view} = View.try_add_node_to_active(sender, view0)
      :ok = Hyparview.EventHandler.add_node(sender, view)
      view
    else
      :ok = JoinFailed.send!(join, view0)
      :ok = debug("JOIN rejected by has not free slot in active view")
      view0
    end
  end

  def handle(%Join{} = join, view) do
    :ok = JoinFailed.send!(join, view)
    view
  end

  # private functions

  @spec maybe_send_forward_join(View.t(), t()) :: :ok
  defp maybe_send_forward_join(view, join) do
    :ok = ForwardJoin.broadcast!(join, view)
    :ok = JoinAccepted.send!(join, view)
  end
end
