defmodule Hyparview.Messages.ForwardJoin do
  @moduledoc """
  FORWARDJOIN request abstraction module
  """

  import Logger

  alias __MODULE__
  alias Hyparview.Config
  alias Hyparview.View
  alias Hyparview.Utils
  alias Hyparview.Messages.Join
  alias Hyparview.Messages.Connect
  alias Hyparview.PeerManager

  defstruct sender: Node.self(),
            joined_node: nil,
            ttl: Config.active_random_walk_length()

  @type t :: %ForwardJoin{
          sender: Node.t(),
          joined_node: Node.t(),
          ttl: non_neg_integer()
        }

  @spec new(join: struct(), ttl: non_neg_integer()) :: t()
  def new(options) when is_list(options) do
    %ForwardJoin{
      sender: Node.self(),
      joined_node: joined_node(options),
      ttl: ttl(options)
    }
  end

  @doc """
  Send to all other nodes in the active view a ForwardJoin request containing the new node.
  """
  @spec broadcast!(Join.t(), View.t()) :: :ok
  def broadcast!(%Join{sender: sender} = join, %View{active: active}) do
    active
    |> MapSet.delete(sender)
    |> PeerManager.fanout(new(join: join))
  catch
    _ -> :ok
  end

  @doc """
  1. If the time to live is equal to zero or if the number of nodes
     in p’s active view is equal to one, it will add the new node to its active view.
     This step is performed even if a random node must be dropped from the active view.
     In the later case, the node being ejected from the active view receives a DISCONNECT notification.

  2. If the time to live is equal to PRWL, p will insert the new node into its passive view.

  3. The time to live field is decremented.

  4. If, at this point, n has not been inserted in p’s active view,
     p will forward the request to a random node in its active view
     (different from the one from which the request was received).
  """
  @spec handle(t(), View.t()) :: {:ok, View.t()} | {{:error, reason :: term()}, View.t()}
  def handle(%ForwardJoin{ttl: 0, joined_node: joined_node}, view) do
    :ok = debug(fn -> "FORWARDJOIN: out of ttl, try add #{joined_node} to active" end)
    :ok = Hyparview.EventHandler.add_node(joined_node, view)
    :ok = Connect.send!(joined_node)
    View.try_add_node_to_active(joined_node, view)
  end

  # In case of active_view is empty, simply add the joined node to its active view.
  def handle(%ForwardJoin{joined_node: joined_node}, %View{active: %MapSet{map: active}} = view)
      when map_size(active) == 0 do
    :ok = debug(fn -> "FORWARDJOIN empty active, try add #{joined_node} to active" end)
    :ok = Hyparview.EventHandler.add_node(joined_node, view)
    :ok = Connect.send!(joined_node)
    View.try_add_node_to_active(joined_node, view)
  end

  # In case of other than those above,
  #  1. If TTL equal to PRWL, insert the joined node into its passive view
  #  2. The TTL is decremented and forward the message.
  def handle(
        %ForwardJoin{ttl: prwl, joined_node: joined_node} = forward_join,
        %View{prwl: prwl} = view
      ) do
    :ok = debug(fn -> "FORWARDJOIN ttl == prwl, try add #{joined_node} to passive" end)

    :ok =
      view
      |> View.trim_and_add_to_passive(forward_join.joined_node)
      |> forward(forward_join)

    {:ok, view}
  end

  def handle(%ForwardJoin{} = forward_join, view) do
    _ = forward(view, forward_join)
    {:ok, view}
  end

  # private functions

  @spec forward(View.t(), t()) :: :ok
  defp forward(view, forward_join) do
    if MapSet.member?(view.active, forward_join.joined_node) do
      view.active
      |> MapSet.delete(forward_join.joined_node)
      |> MapSet.delete(forward_join.sender)
      |> Utils.choose_node()
      |> PeerManager.send_message(%{forward_join | ttl: forward_join.ttl - 1})
    else
      :ok
    end
  end

  @spec joined_node([join: Join.t()] | []) :: Node.t() | none()
  defp joined_node(options) do
    case options[:join] do
      nil -> throw(:join_not_given)
      join when is_map(join) -> join.sender
    end
  end

  @spec ttl([ttl: non_neg_integer()] | []) :: non_neg_integer()
  defp ttl(options) do
    case options[:ttl] do
      nil -> Config.active_random_walk_length()
      ttl when is_integer(ttl) -> ttl
    end
  end
end
