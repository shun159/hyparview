defmodule Hyparview.DefaultHandler do
  @moduledoc """
  Hyparview Event callback module example
  """

  import Logger, only: [info: 1, warn: 1]

  alias Hyparview.View

  @spec joining() :: map()
  def joining, do: Map.new()

  @spec joined(View.t(), state :: term()) :: {:ok, term()}
  def joined(_view, state) do
    :ok = info("JOINED")
    {:ok, state}
  end

  @spec connected(Node.t(), state :: term()) :: {:ok, term()}
  def connected(node, state) do
    :ok = info("CONNECTED node: #{node}")
    {:ok, state}
  end

  @spec disconnected(Node.t(), state :: term()) :: {:ok, term()}
  def disconnected(node, state) do
    :ok = warn("DISCONNECTED node: #{node}")
    {:ok, state}
  end
end
