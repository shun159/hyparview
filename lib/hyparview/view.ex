defmodule Hyparview.View do
  @moduledoc """
  Hyparview VIEW struct and functions
  """

  alias __MODULE__
  alias Hyparview.Config
  alias Hyparview.NodeMonitor

  defstruct active: MapSet.new(),
            passive: Config.contact_nodes(),
            active_size: Config.active_view_size(),
            passive_size: Config.passive_view_size(),
            arwl: Config.active_random_walk_length(),
            prwl: Config.passive_random_walk_length()

  @opaque view_t :: MapSet.t(Node.t())

  @type t :: %View{
          active: view_t(),
          passive: view_t(),
          active_size: non_neg_integer(),
          passive_size: non_neg_integer(),
          arwl: non_neg_integer(),
          prwl: non_neg_integer()
        }

  @spec has_free_slot_in_active_view?(t()) :: boolean()
  def has_free_slot_in_active_view?(%View{active: %MapSet{map: active}} = view),
    do: view.active_size > map_size(active)

  @spec move_passive_to_active(View.t(), Node.t()) :: View.t()
  def move_passive_to_active(view, node) do
    passive = MapSet.delete(view.passive, node)
    active = MapSet.put(view.active, node)
    :ok = NodeMonitor.add_node(node)
    %{view | active: active, passive: passive}
  end

  @spec move_active_to_passive(Node.t(), View.t()) :: View.t()
  def move_active_to_passive(node, view) do
    active = MapSet.delete(view.active, node)
    passive = MapSet.put(view.passive, node)
    _ = Node.disconnect(node)
    %{view | active: active, passive: passive}
  end

  @spec is_node_already_added?(Node.t(), t()) :: boolean()
  def is_node_already_added?(node, view) do
    [view.active, view.passive]
    |> Enum.map(&MapSet.member?(&1, node))
    |> Enum.any?()
  end

  # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
  @spec try_add_node_to_active(Node.t(), t()) :: {:ok, t()} | {{:error, :failed_to_connect}, t()}
  def try_add_node_to_active(node, view) do
    case Node.connect(node) do
      false -> {{:error, :failed_to_connect}, view}
      true -> {:ok, try_add_node_to_active_1(node, view)}
    end
  end

  @spec trim_and_add_to_passive(View.t(), Node.t() | MapSet.t()) :: View.t()
  def trim_and_add_to_passive(%View{} = view, %MapSet{} = nodes) do
    nodes
    |> MapSet.delete(Node.self())
    |> Enum.reduce(view, fn node, acc -> trim_and_add_to_passive(acc, node) end)
  end

  def trim_and_add_to_passive(view, node) when node != node() do
    if not is_node_already_added?(node, view) do
      passive =
        view.passive
        |> Enum.split(view.passive_size)
        |> Kernel.elem(0)
        |> MapSet.new()
        |> MapSet.put(node)

      %{view | passive: passive}
    else
      view
    end
  end

  def trim_and_add_to_passive(view, _node) do
    view
  end

  # private funtions

  @spec try_add_node_to_active_1(Node.t(), t()) :: t()
  defp try_add_node_to_active_1(node, view) do
    view
    |> trim_active()
    |> move_passive_to_active(node)
  end

  @spec trim_active(t()) :: t()
  defp trim_active(view) do
    dropped_nodes = select_drop_nodes_from_active(view)
    :ok = Enum.each(dropped_nodes, &NodeMonitor.schedule_delete_node(&1, 25_000))
    Enum.reduce(dropped_nodes, view, &move_active_to_passive/2)
  end

  @spec select_drop_nodes_from_active(t()) :: MapSet.t()
  defp select_drop_nodes_from_active(view) do
    view.active
    |> Enum.shuffle()
    |> Enum.split(view.active_size - 1)
    |> Kernel.elem(1)
    |> MapSet.new()
  end
end
