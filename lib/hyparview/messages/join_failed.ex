defmodule Hyparview.Messages.JoinFailed do
  @moduledoc """
  A Message for JOIN failed
  """

  alias __MODULE__
  alias Hyparview.View
  alias Hyparview.Config
  alias Hyparview.Utils
  alias Hyparview.Messages.Join
  alias Hyparview.PeerManager

  defstruct sender: Node.self(),
            view: %View{}

  @type t :: %JoinFailed{
          sender: Node.t(),
          view: View.t()
        }

  @spec new(View.t()) :: t()
  def new(view) do
    %JoinFailed{sender: Node.self(), view: view}
  end

  @spec send!(Join.t(), View.t()) :: :ok
  def send!(%Join{sender: sender}, view) do
    join_failed = new(view)
    :ok = PeerManager.send_message(sender, join_failed)
  end

  @doc """
  Handler function for JoinFailed received node.
  If the Join request Failed, Join receiver send back a JoinFailed
  message that includes its active view to the Join sender.
  When the JoinFailed received, Join sender sends a Join request again
  to a node that chosen from the active view, except the Failed node and  Bootstrap nodes.

      _time_ref = JoinFailed.handle(join_failed, state.view)
      {:noreply, state}
  """
  @spec handle(t(), View.t()) :: reference()
  def handle(%JoinFailed{} = join_failed, view) do
    join_failed
    |> choose_node(view)
    |> PeerManager.send_after(Join.new(), 1000)
  end

  # private functions

  @spec prohibited_nodes(t()) :: MapSet.t()
  defp prohibited_nodes(%JoinFailed{sender: sender, view: view}) do
    Config.contact_nodes()
    |> MapSet.put(sender)
    |> MapSet.intersection(view.active)
  end

  @spec choose_node(t(), View.t()) :: Node.t()
  defp choose_node(join_failed, view) do
    prohibited = prohibited_nodes(join_failed)

    view.active
    |> Enum.filter(&(not (&1 in prohibited)))
    |> MapSet.new()
    |> Utils.choose_node()
  end
end
