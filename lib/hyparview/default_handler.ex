defmodule Hyparview.DefaultHandler do
  @moduledoc """
  Hyparview Event callback module example
  """

  @behaviour Hyparview.Event

  import Logger, only: [info: 1, warn: 1]

  alias Hyparview.View

  @spec add_node(Node.t(), View.t()) :: :ok
  def add_node(node, _view) do
    :ok = info("CONNECTED node: #{node} to #{Node.self()}")
  end

  @spec del_node(Node.t(), View.t()) :: :ok
  def del_node(node, _view) do
    :ok = warn("DISCONNECTED node: #{node} from #{Node.self()}")
  end
end
