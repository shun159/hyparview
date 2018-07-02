defmodule Hyparview.Messages.Connect do
  @moduledoc """
  Connect message
  """

  alias __MODULE__
  alias Hyparview.PeerManager
  alias Hyparview.View

  defstruct sender: Node.self()

  @type t() :: %Connect{sender: Node.t()}

  @spec new() :: t()
  def new do
    %Connect{}
  end

  @spec send!(Node.t()) :: :ok
  def send!(joined_node) do
    _ = PeerManager.send_message(joined_node, new())
  end

  @spec handle(t(), View.t()) :: View.t()
  def handle(%Connect{sender: sender}, view) do
    _ = Hyparview.EventHandler.add_node(sender, view)
    {_, view} = View.try_add_node_to_active(sender, view)
    view
  end
end
