defmodule Hyparview.Utils do
  @moduledoc false

  alias :rand, as: Rand

  @spec random_delay(base_time :: non_neg_integer()) :: non_neg_integer()
  def random_delay(base_time) do
    Rand.uniform_real()
    |> Kernel.round()
    |> Kernel.+(1)
    |> Kernel.*(base_time)
  end

  @spec choose_node(MapSet.t(Node.t())) :: Node.t() | nil
  def choose_node(nodes0) do
    nodes = MapSet.delete(nodes0, Node.self())

    if MapSet.size(nodes) > 0 do
      node_idx =
        nodes
        |> MapSet.delete(Node.self())
        |> MapSet.size()
        |> Rand.uniform()
        |> Kernel.-(1)

      Enum.at(nodes, node_idx)
    else
      nil
    end
  end
end
