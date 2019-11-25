defmodule Hyparview.Membership do
  @moduledoc false

  use GenServer

  import Logger

  alias __MODULE__, as: State
  alias Hyparview.Config
  alias Hyparview.Messages

  defstruct active_view: MapSet.new(),
            passive_view: MapSet.new(),
            arwl: 0,
            prwl: 0,
            shuffle_interval: 0,
            join_interval: 0,
            join_timeout: 0,
            neighbor_interval: 0,
            active_view_size: 0,
            passive_view_size: 0,
            joined?: false,
            subscriber: MapSet.new()

  # API functions

  @spec start_link() :: GenServer.on_start()
  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # GenServer callback functions

  @impl GenServer
  def init(_args) do
    :ok = info("Membership started on #{Node.self()}")
    :ok = NodeMonitor.subscribe()
    {:ok, init_state(), {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    _ = delay_cast(:send_join, state.join_interval)
    _ = delay_cast(:send_neighbor, state.neighbor_interval)
    _ = delay_cast(:send_shuffle, state.shuffle_interval)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_active_view, _from, state) do
    {:reply, state.active_view, state}
  end

  @impl GenServer
  def handle_call(:get_passive_view, _from, state) do
    {:reply, state.passive_view, state}
  end

  @impl GenServer
  def handle_call({:subscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscriber: MapSet.put(state.subscribier, pid)}}
  end

  @impl GenServer
  def handle_cast(%{msg: :join} = join, state0) do
    :ok = info("JOIN request received from #{join.sender}")
    state = handle_join(join, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :join_ack} = join_ack, state0) do
    :ok = info("JOIN_ACK message received from #{join_ack.sender}")
    state = handle_join_ack(join_ack, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :forward_join} = forward_join, state0) do
    :ok = debug("FORWARDJOIN received from #{forward_join.sender}")
    state = handle_forward_join(forward_join, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :neighbor, sender: sender} = neighbor, state0) do
    :ok = debug("NEIGHBOR received from #{sender}")
    state = handle_neighbor(neighbor, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :neighbor_ack, sender: sender} = neighbor_ack, state0) do
    :ok = debug("NEIGHBOR_ACK received from #{sender}")
    state = handle_neighbor_ack(neighbor_ack, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :neighbor_nak, sender: sender} = neighbor_nak, state0) do
    :ok = debug("NEIGHBOR_NAK received from #{sender}")
    state = handle_neighbor_nak(neighbor_nak, state0)
    _ = delay_cast(:send_neighbor, state.neighbor_interval)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :shuffle} = shuffle, state0) do
    :ok = debug("SHUFFLE received from #{shuffle.sender}")
    state = handle_shuffle(shuffle, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :shuffle_reply} = shuffle_reply, state0) do
    :ok = debug("SHUFFLE received from #{shuffle_reply.sender}")
    state = handle_shuffle_reply(shuffle_reply, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%{msg: :disconnect} = disconnect, state0) do
    :ok = debug("DISCONNECT received from #{disconnect.sender}")
    state = handle_disconnect(disconnect, state0)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:send_join, %State{joined?: true} = state) do
    # Already JOINED, ignore this request
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:send_join, %State{} = state) do
    case do_join(state) do
      :ok ->
        {:noreply, state}

      {:error, node} ->
        handle_info({:join_timeout, node}, state)
    end
  end

  @impl GenServer
  def handle_cast(:send_neighbor, %State{} = state) do
    case do_neighbor(state) do
      :ok ->
        {:noreply, state}

      {:error, :nonode} ->
        :ok = warn("Couldn't send neighbor request, because of passive view empty")
        {:noreply, state}

      {:error, node} ->
        {:noreply, %{state | passive_view: MapSet.delete(state.passive_view, node)}}
    end
  end

  @impl GenServer
  def handle_cast(:send_shuffle, %State{} = state) do
    _ = delay_cast(:send_shuffle, state.shuffle_interval)
    _ = do_shuffle(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:join_timeout, node}, state) do
    :ok = warn("Failed to send JOIN message, retry after join_interval")
    _ = NodeMonitor.unregister(node)
    _ = delay_cast(:send_join, state.join_interval)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:node_event, _node, :up}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:node_event, node, :down}, state0) do
    :ok = warn("Neighbor DOWN detected: #{node}")
    state = handle_down(node, state0)
    _ = do_neighbor(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(info, state) do
    :ok = warn("unhandled message received: #{inspect(info)} on handle_info/2")
    {:noreply, state}
  end

  # private functions

  @spec handle_join(Messages.join_t, %State{}) :: %State{}
  defp handle_join(join, state0) do
    state = add_node_active_view(join.sender, state0)
    :ok = bcast_forward_join(join.sender, state)
    :ok = send_join_ack_message(join.sender, join.tref, state)
    %{state | joined?: true}
  end

  @spec handle_join_ack(Messages.join_ack_t, %State{}) :: %State{}
  defp handle_join_ack(join_ack, state0) do
    :ok = cancel_timer(join_ack.tref)
    state = add_node_active_view(join_ack.sender, state0)
    %{state | joined?: true}
  end

  @spec handle_forward_join(Messages.forward_join_t, %State{}) :: %State{}
  defp handle_forward_join(%{ttl: ttl} = forward_join, state0) do
    cond do
      ttl == state0.prwl ->
        state = add_node_passive_view(forward_join.new_node, state0)
        :ok = forward_forward_join(forward_join, state)
        state

      ttl == 0 or MapSet.size(state0.active_view) == 0 ->
        _ = do_neighbor(forward_join.new_node, state0)
        state0

      true ->
        :ok = forward_forward_join(forward_join, state0)
        state0
    end
  end

  @spec handle_neighbor(Messages.neighbor_t, %State{}) :: %State{}
  defp handle_neighbor(%{priority: :high, sender: sender}, state0) do
    state = add_node_active_view(sender, state0)
    :ok = send_neighbor_ack(sender)
    state
  end

  defp handle_neighbor(%{sender: sender}, state0) do
    if (state0.active_view_size - MapSet.size(state0.active_view)) > 0 do
      state = add_node_active_view(sender, state0)
      :ok = send_neighbor_ack(sender)
      state
    else
      :ok = send_neighbor_nak(sender, state0)
      _ = NodeMonitor.unregister(sender)
      state0
    end
  end

  @spec handle_neighbor_ack(Messages.neighbor_ack_t, %State{}) :: %State{}
  defp handle_neighbor_ack(neighbor_ack, state0) do
    add_node_active_view(neighbor_ack.sender, state0)
  end

  @spec handle_neighbor_nak(Messages.neighbor_nak_t, %State{}) :: %State{}
  defp handle_neighbor_nak(neighbor_nak, state0) do
    _ = NodeMonitor.unregister(neighbor_nak.sender)
    active_view = MapSet.delete(state0.active_view, neighbor_nak.sender)
    %{state0 | active_view: active_view}
  end

  @spec handle_shuffle(Messages.shuffle_t, %State{}) :: %State{}
  defp handle_shuffle(shuffle, state0) do
    if shuffle.ttl > 1 and MapSet.size(state0.active_view) > 1 do
      :ok = forward_shuffle(shuffle, state0)
      state0
    else
      combined_view = combine_with_remote_view(shuffle, state0)
      state = merge_remote_passive_view(shuffle, state0)
      :ok = send_shuffle_reply(shuffle.sender, combined_view)
      state
    end
  end

  @spec handle_shuffle_reply(Messages.shuffle_reply_t, %State{}) :: %State{}
  defp handle_shuffle_reply(shuffle_reply, state0) do
    shuffle_reply.combined_view
    |> MapSet.union(state0.passive_view)
    |> MapSet.difference(state0.active_view)
    |> MapSet.delete(Node.self())
    |> add_nodes_passive_view(state0)
  end

  @spec handle_disconnect(Messages.disconnect_t, %State{}) :: %State{}
  defp handle_disconnect(disconnect, state0) do
    _ = NodeMonitor.unregister(disconnect.sender)
    active_view = MapSet.delete(state0.active_view, disconnect.sender)
    passive_view = MapSet.put(state0.passive_view, disconnect.sender)
    %{state0 | active_view: active_view, passive_view: passive_view}
  end

  @spec handle_down(Node.t(), %State{}) :: %State{}
  defp handle_down(node, %State{active_view: active_view, passive_view: passive_view} = state0) do
    _ = NodeMonitor.unregister(node)
    active_view = MapSet.delete(active_view, node)
    passive_view = MapSet.delete(passive_view, node)
    :ok = notify_event(node, :down, state0)
    %{state0 | active_view: active_view, passive_view: passive_view}
  end

  @spec merge_remote_passive_view(Messages.shuffle_t(), %State{}) :: %State{}
  defp merge_remote_passive_view(shuffle, state) do
    state.passive_view
    |> MapSet.union(shuffle.passive_view)
    |> MapSet.union(shuffle.active_view)
    |> MapSet.delete(Node.self())
    |> add_nodes_passive_view(state)
  end

  @spec add_nodes_passive_view(MapSet.t(Node.t()), %State{}) :: %State{}
  defp add_nodes_passive_view(remote_passive_view, state) do
    Enum.reduce(
      remote_passive_view,
      state,
      &add_node_passive_view(&1, &2)
    )
  end

  @spec add_node_passive_view(Node.t(), %State{}) :: %State{}
  defp add_node_passive_view(new_node, state)
       when new_node == node(),
       do: state

  defp add_node_passive_view(new_node, state0) do
    if member_of_view?(new_node, state0) do
      state0
    else
      state = drop_random_elem_from_passive_view(state0)
      %{state | passive_view: MapSet.put(state.passive_view, new_node)}
    end
  end

  @spec add_node_active_view(Node.t(), %State{}) :: %State{}
  defp add_node_active_view(node, state0) do
    if !member_of_active_view?(node, state0) and !(Node.self() == node) do
      _ = NodeMonitor.register(node)
      :ok = notify_event(node, :up, state0)
      state = drop_random_elem_from_active_view(state0)
      active_view = MapSet.put(state.active_view, node)
      passive_view = MapSet.delete(state.passive_view, node)
      %{state0 | active_view: active_view, passive_view: passive_view}
    else
      state0
    end
  end

  @spec drop_random_elem_from_active_view(%State{}) :: %State{}
  defp drop_random_elem_from_active_view(state0) do
    if state0.active_view_size - MapSet.size(state0.active_view) < 1 do
      case Hyparview.Utils.select_node(state0.active_view) do
        {:ok, node} ->
          :ok = notify_event(node, :down, state0)
          drop_elem_from_active_view(node, state0)

        {:error, _} ->
          state0
      end
    else
      state0
    end
  end

  @spec member_of_view?(Node.t(), %State{}) :: boolean
  defp member_of_view?(node, state) do
    MapSet.member?(state.active_view, node) or
      MapSet.member?(state.passive_view, node)
  end

  @spec member_of_active_view?(Node.t(), %State{}) :: boolean
  defp member_of_active_view?(node, state),
    do: MapSet.member?(state.active_view, node)

  @spec send_join_message(Node.t()) :: :ok
  defp send_join_message(node) do
    tref = Process.send_after(self(), {:join_timeout, node}, 1000)
    :ok = send_message(node, Messages.join(tref))
  end

  @spec send_join_ack_message(Node.t(), reference(), %State{}) :: :ok
  defp send_join_ack_message(node, tref, state) do
    :ok = send_message(node, Messages.join_ack(tref, state.passive_view))
  end

  @spec send_disconnect(Node.t()) :: :ok
  defp send_disconnect(node) do
    :ok = send_message(node, Messages.disconnect())
  end

  @spec bcast_forward_join(Node.t(), %State{}) :: :ok
  defp bcast_forward_join(new_node, state) do
    state.active_view
    |> MapSet.delete(new_node)
    |> send_message(
      Messages.forward_join(
        new_node: new_node,
        ttl: state.arwl,
        path: MapSet.new([Node.self()])
      )
    )
  end

  @spec forward_forward_join(Messages.forward_join_t(), %State{}) :: :ok
  defp forward_forward_join(forward_join, state) do
    selected_node =
      state.active_view
      |> MapSet.delete(forward_join.sender)
      |> MapSet.difference(forward_join.path)
      |> Hyparview.Utils.select_node()

    case selected_node do
      {:ok, node} ->
        path = MapSet.put(forward_join.path, Node.self())
        msg = %{forward_join | ttl: forward_join.ttl - 1, path: path}
        send_message(node, msg)

      {:error, _} ->
        :ok = warn("Failed to forward the forward_join")
    end
  end

  @spec forward_shuffle(Messages.shuffle_t(), %State{}) :: :ok
  defp forward_shuffle(shuffle, state) do
    selected_node =
      state.active_view
      |> MapSet.delete(shuffle.sender)
      |> MapSet.difference(shuffle.path)
      |> Hyparview.Utils.select_node()

    case selected_node do
      {:ok, node} ->
        path = MapSet.put(shuffle.path, Node.self())
        msg = %{shuffle | ttl: shuffle.ttl - 1, path: path}
        send_message(node, msg)

      {:error, _} ->
        :ok = warn("Failed to forward the shuffle")
    end
  end

  @spec send_neighbor(Node.t(), %State{}) :: :ok
  defp send_neighbor(node, state),
    do: send_message(node, Messages.neighbor(neighbor_priority(state)))

  @spec send_neighbor_ack(Node.t()) :: :ok
  defp send_neighbor_ack(node),
    do: send_message(node, Messages.neighbor_ack())

  @spec send_neighbor_nak(Node.t(), %State{}) :: :ok
  defp send_neighbor_nak(node, state),
    do: send_message(node, Messages.neighbor_nak(state.passive_view))

  @spec send_shuffle(Node.t(), %State{}) :: :ok
  defp send_shuffle(node, state) do
    send_message(
      node,
      Messages.shuffle(
        passive_view: state.passive_view,
        active_view: state.active_view,
        ttl: state.prwl,
        path: MapSet.new([Node.self()])
      )
    )
  end

  @spec send_shuffle_reply(Node.t(), MapSet.t(Node.t())) :: :ok
  defp send_shuffle_reply(node, combined_view),
    do: send_message(node, Messages.shuffle_reply(combined_view))

  @spec drop_elem_from_active_view(Node.t(), %State{}) :: %State{}
  defp drop_elem_from_active_view(node, state) do
    active_view = MapSet.delete(state.active_view, node)
    passive_view = MapSet.put(state.passive_view, node)
    :ok = send_disconnect(node)
    %{state | active_view: active_view, passive_view: passive_view}
  end

  @spec drop_random_elem_from_passive_view(%State{}) :: %State{}
  defp drop_random_elem_from_passive_view(state0) do
    if MapSet.size(state0.passive_view) >= state0.passive_view_size do
      case Hyparview.Utils.select_node(state0.passive_view) do
        {:ok, drop_node} ->
          %{state0 | passive_view: MapSet.delete(state0.passive_view, drop_node)}

        {:error, _} ->
          state0
      end
    else
      state0
    end
  end

  @spec do_join(%State{}) :: :ok | {:error, reason :: term()}
  defp do_join(state) do
    case Hyparview.Utils.select_node(state.passive_view) do
      {:ok, node} ->
        do_join(node, state)

      {:error, :nonode} = error ->
        error
    end
  end

  @spec do_join(Node.t(), %State{}) :: :ok | {:error, reason :: term()}
  defp do_join(node, _state) do
    case NodeMonitor.register(node) do
      :ok ->
        send_join_message(node)

      {:error, _reason} ->
        {:error, node}
    end
  end

  @spec do_neighbor(%State{}) :: :ok | {:error, reason :: term()}
  defp do_neighbor(state) do
    case Hyparview.Utils.select_node(state.passive_view) do
      {:ok, node} ->
        do_neighbor(node, state)

      {:error, :nonode} = error ->
        error
    end
  end

  @spec do_neighbor(Node.t(), %State{}) :: :ok | {:error, reason :: term()}
  defp do_neighbor(node, state) do
    case NodeMonitor.register(node) do
      :ok ->
        send_neighbor(node, state)

      {:error, _reason} ->
        {:error, node}
    end
  end

  @spec do_shuffle(%State{}) :: :ok | {:error, reason :: term()}
  defp do_shuffle(state) do
    case Hyparview.Utils.select_node(state.active_view) do
      {:ok, node} ->
        do_shuffle(node, state)

      {:error, :nonode} = error ->
        error
    end
  end

  @spec do_shuffle(Node.t(), %State{}) :: :ok | {:error, reason :: term()}
  defp do_shuffle(node, state) do
    case NodeMonitor.register(node) do
      :ok ->
        send_shuffle(node, state)

      {:error, _reason} ->
        {:error, node}
    end
  end

  @spec combine_with_remote_view(Messages.shuffle_t(), %State{}) :: MapSet.t(Node.t())
  defp combine_with_remote_view(shuffle, state) do
    state.passive_view
    |> MapSet.difference(shuffle.active_view)
    |> MapSet.difference(shuffle.passive_view)
    |> Enum.split(MapSet.size(shuffle.active_view))
    |> elem(0)
    |> MapSet.new()
  end

  @spec neighbor_priority(%State{}) :: :low | :high
  defp neighbor_priority(%State{active_view: active_view}),
    do: if(MapSet.size(active_view) > 0, do: :low, else: :high)

  @spec send_message(MapSet.t(Node.t()) | Node.t() | any, Messages.t()) :: :ok
  defp send_message({:error, :nonode}, _),
    do: warn("Failed to send message due to nonode")

  defp send_message(nodes, msg) when is_map(nodes),
    do: Enum.each(nodes, &send_message(&1, msg))

  defp send_message(node, msg) when is_atom(node),
    do: GenServer.cast({__MODULE__, node}, msg)

  @spec delay_cast(term, non_neg_integer) :: reference
  defp delay_cast(msg, time),
    do: Process.send_after(__MODULE__, {:"$gen_cast", msg}, time)

  @spec cancel_timer(reference | term) :: :ok
  defp cancel_timer(ref) do
    if is_reference(ref), do: Process.cancel_timer(ref)
    :ok
  end

  @spec notify_event(Node.t(), :up | :down, %State{}) :: :ok
  defp notify_event(node, evt, state),
    do:
      Enum.each(
        state.subscriber,
        &Process.send(&1, {:membership, node, evt}, [])
      )

  @spec init_state() :: %State{}
  defp init_state do
    seed = :erlang.phash2({Node.self(), :erlang.monotonic_time()})
    {_, _} = :rand.seed(:exsplus, seed)

    %State{
      passive_view: MapSet.new(Config.contact_nodes()),
      arwl: Config.arwl(),
      prwl: Config.prwl(),
      shuffle_interval: Config.shuffle_interval(),
      join_interval: Config.join_interval(),
      join_timeout: Config.join_timeout(),
      neighbor_interval: Config.neighbor_interval(),
      active_view_size: Config.active_view_size(),
      passive_view_size: Config.passive_view_size()
    }
  end
end
