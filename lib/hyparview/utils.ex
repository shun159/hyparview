defmodule Hyparview.Utils do
  @moduledoc false

  @spec select_node(MapSet.t(Node.t())) :: {:ok, Node.t()} | {:error, :nonode}
  def select_node(nodes) do
    case MapSet.size(nodes) do
      0 ->
        {:error, :nonode}

      len ->
        node = Enum.at(nodes, :rand.uniform(len) - 1)
        {:ok, node}
    end
  end
end
