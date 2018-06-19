defmodule Hyparview.Messages.Disconnect do
  @moduledoc """
  DISCONNECT notification
  """

  alias __MODULE__
  alias Hyparview.PeerManager
  alias Hyparview.View

  defstruct sender: Node.self()

  @type t :: %Disconnect{
          sender: Node.t()
        }

  @spec new() :: t()
  def new, do: %Disconnect{sender: Node.self()}

  @spec new(Node.t()) :: t()
  def new(node) do
    %Disconnect{sender: node}
  end

  @spec notify(Node.t(), View.t()) :: View.t()
  def notify(node, view) do
    :ok = PeerManager.send_message(node, new())
    View.move_active_to_passive(node, view)
  end

  @spec handle(t(), View.t()) :: View.t()
  def handle(%Disconnect{sender: sender}, view) do
    View.move_active_to_passive(sender, view)
  end
end
