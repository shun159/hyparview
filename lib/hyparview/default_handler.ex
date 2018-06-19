defmodule Hyparview.DefaultHandler do
  @moduledoc """
  Hyparview Event callback module example
  """

  import Logger, only: [info: 1, warn: 1]

  alias Hyparview.View

  @spec joining() :: {:ok, term()}
  def joining, do: {:ok, Map.new()}

  @spec joined(View.t(), state :: term()) :: {:ok, term()}
  def joined(_view, state) do
    :ok = info("JOINED")
    {:ok, state}
  end

  @spec add_node(Node.t(), View.t(), state :: term()) :: {:ok, term()}
  def add_node(node, _view, state) do
    :ok = info("CONNECTED node: #{node}")
    {:ok, state}
  end

  @spec del_node(Node.t(), View.t(), state :: term()) :: {:ok, term()}
  def del_node(node, _view, state) do
    :ok = warn("DISCONNECTED node: #{node}")
    {:ok, state}
  end
end
