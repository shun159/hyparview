defmodule Hyparview.NodeMonitor do
  @moduledoc """
  Node monitor
  """

  use GenServer

  require Record
  require Logger

  alias Hyparview.Messages.Disconnect
  alias Hyparview.PeerManager
  alias :ets, as: ETS

  Record.defrecord(
    :monitor,
    node: nil,
    mon_ref: nil
  )

  @type monitor ::
          record(
            :monitor,
            node: Node.t(),
            mon_ref: reference()
          )

  # API functions

  @doc """
  :ok = NodeMonitor.add(:"node1@127.0.0.1")
  """
  @spec add_node(Node.t()) :: :ok
  def add_node(node) do
    :ok = GenServer.call(__MODULE__, {:add, node})
  end

  @doc """
  Demonitor the node and remove from Node list, and then send `DISCONNECT` message 

     :ok = NodeMonitor.delete_node(:"node1@127.0.0.1")
  """
  @spec delete_node(Node.t()) :: :ok
  def delete_node(node) do
    :ok = GenServer.call(__MODULE__, {:del, node})
  end

  @doc """
  :ok = NodeMonitor.schedule_delete_node(:"node1@127.0.0.1", _base_time = 60_000)
  or
  :ok = NodeMonitor.schedule_delete_node(MapSet.new(:"node1@127.0.0.1"), _base_time = 60_000)
  """
  @spec schedule_delete_node(MapSet.t(Node.t()), non_neg_integer()) :: :ok
  @spec schedule_delete_node(Node.t(), non_neg_integer()) :: :ok
  def schedule_delete_node(%MapSet{} = nodes, base_time) do
    :ok = Enum.each(nodes, &schedule_delete_node(&1, base_time))
  end

  def schedule_delete_node(node, base_time) do
    :ok = GenServer.cast(__MODULE__, {:schedule_del, node, base_time})
  end

  @doc """
  if NodeMonitor.has_monitor(:"node1@127.0.0.1") do
    # do_something...
  else
    # do_something_else...
  end
  """
  @spec has_monitor(Node.t()) :: boolean()
  def has_monitor(node), do: ETS.member(:monitor, node)

  # GenServer Callback functions

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    :ok = Logger.debug("Started node_monitor")
    :ok = create_monitor_table()
    {:ok, :no_state}
  end

  def handle_call({:add, r_node}, _from, state) do
    true = do_add_node(r_node)
    {:reply, :ok, state}
  end

  def handle_call({:del, r_node}, _from, state) do
    true = do_del_node(r_node)
    {:reply, :ok, state}
  end

  def handle_cast({:schedule_del, r_node, base_time}, state) do
    delay = Hyparview.Utils.random_delay(base_time)
    _tref = Process.send_after(self(), {:del, r_node}, delay)
    {:noreply, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _mon_ref, _, {_, r_node}, _reason}, state) do
    _ = send(PeerManager, Disconnect.new(r_node))
    true = do_del_node(r_node)
    {:noreply, state}
  end

  def handle_info({:del, r_node}, state) do
    true = do_del_node(r_node)
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  # private functions

  @spec create_monitor_table() :: :ok
  defp create_monitor_table do
    :monitor =
      ETS.new(:monitor, [
        :set,
        :protected,
        :named_table,
        {:keypos, monitor(:node) + 1},
        {:read_concurrency, true}
      ])

    :ok
  end

  @spec do_add_node(Node.t()) :: true
  defp do_add_node(node) do
    mon_ref = Process.monitor({PeerManager, node})
    entry = monitor(node: node, mon_ref: mon_ref)
    true = ETS.insert(:monitor, entry)
  end

  @spec do_del_node(Node.t()) :: true
  defp do_del_node(node) do
    case lookup(node) do
      nil ->
        true

      mon_ref ->
        _ = Process.demonitor(mon_ref)
        true = ETS.delete(:monitor, node)
    end
  end

  @spec lookup(reference() | Node.t() | any()) :: Node.t() | reference() | nil
  defp lookup(node) when is_atom(node) do
    case ETS.lookup(:monitor, node) do
      [monitor(mon_ref: mon_ref)] -> mon_ref
      [] -> nil
    end
  end

  defp lookup(mon_ref) when is_reference(mon_ref) do
    # match_spec:
    #   fn(monitor(node: node, mon_ref: mon_ref)) when node == :a -> mon_ref end)
    match_spec = [{{:monitor, :"$1", :"$2"}, [{:==, :"$2", mon_ref}], [:"$1"]}]

    case ETS.select(:monitor, match_spec) do
      [node_name] when is_atom(node_name) -> node_name
      _ -> nil
    end
  end
end
