defmodule Hyparview.Utils do
  @moduledoc false

  alias :rand, as: Rand

  @spec rand_seed() :: Rand.state()
  def rand_seed do
    Rand.seed(:exsplus, make_seed())
  end

  @spec random_delay(base_time :: non_neg_integer()) :: non_neg_integer()
  def random_delay(base_time) do
    base_time
    |> Kernel.+(1)
    |> Rand.uniform()
    |> Kernel.-(1)
    |> Kernel.+(div(base_time, 2))
  end

  @spec choose_node(MapSet.t(Node.t())) :: Node.t() | nil
  def choose_node(nodes0) do
    nodes = MapSet.delete(nodes0, Node.self())

    if MapSet.size(nodes) > 0 do
      node_idx = randomized_index_of(nodes)
      Enum.at(nodes, node_idx)
    else
      nil
    end
  end

  # private functions

  @spec randomized_index_of(MapSet.t(Node.t())) :: non_neg_integer()
  defp randomized_index_of(nodes) do
    nodes
    |> MapSet.size()
    |> Rand.uniform()
    |> Kernel.-(1)
  end

  @spec make_seed() :: {integer(), integer(), integer()}
  defp make_seed do
    {
      :erlang.phash2([Node.self()]),
      :erlang.monotonic_time(),
      :erlang.unique_integer()
    }
  end
end
