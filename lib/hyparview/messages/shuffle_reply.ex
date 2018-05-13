defmodule Hyparview.Messages.ShuffleReply do
  @moduledoc """
  SHUFFLEREPLY message abstraction module
  """

  alias __MODULE__
  alias Hyparview.Messages.Shuffle
  alias Hyparview.View
  alias Hyparview.PeerManager

  defstruct sender: Node.self(),
            nodes: MapSet.new()

  @type t :: %ShuffleReply{
          sender: Node.t(),
          nodes: MapSet.t(Node.t())
        }

  @doc """
  A ShuffleReply message that includes a number of nodes selected at random from
  q’s passive view equal to the number of nodes received in the Shuffle request.

      shuffle_reply = ShuffleReply.new(view: state.view, shuffle: Shuffle.new())
  """
  @spec new(view: View.t(), shuffle: Shuffle.t()) :: t()
  def new(options \\ []),
    do: %ShuffleReply{nodes: compose_reply_nodes(options), sender: Node.self()}

  @doc """
  Send a SHUFFLEREPLY message to the SHUFFLE sender

      :ok = ShuffleReply.send!(shuffle_reply, :"node1@127.0.0.1")
  """
  @spec send!(ShuffleReply.t(), Node.t()) :: :ok
  def send!(%ShuffleReply{} = shuffle_reply, shuffle_sender),
    do: :ok = PeerManager.send_message(shuffle_sender, shuffle_reply)

  @spec handle(t(), View.t()) :: View.t()
  def handle(%ShuffleReply{nodes: nodes}, view), do: View.trim_and_add_to_passive(view, nodes)

  # private functions

  @spec compose_reply_nodes(view: View.t(), shuffle: Shuffle.t()) :: MapSet.t(Node.t())
  defp compose_reply_nodes(options) do
    view = options[:view] || throw(:not_view_given)
    shuffle = options[:shuffle] || Shuffle.new()
    shuffle_nodes_size = MapSet.size(shuffle.nodes)

    view.passive
    |> Enum.take_random(shuffle_nodes_size)
    |> MapSet.new()
  end
end
