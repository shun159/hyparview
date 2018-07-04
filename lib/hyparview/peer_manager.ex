defmodule Hyparview.PeerManager do
  @moduledoc """
  Hyparview PeerManager module
  """

  import Logger, only: [debug: 1]

  alias :gen_statem, as: GenStatem
  alias :rand, as: Rand

  alias Hyparview.Config
  alias Hyparview.View
  alias Hyparview.Utils
  alias Hyparview.Messages.Join
  alias Hyparview.Messages.JoinAccepted
  alias Hyparview.Messages.JoinFailed
  alias Hyparview.Messages.ForwardJoin
  alias Hyparview.Messages.Shuffle
  alias Hyparview.Messages.ShuffleReply
  alias Hyparview.Messages.Neighbor
  alias Hyparview.Messages.NeighborAccepted
  alias Hyparview.Messages.NeighborRejected
  alias Hyparview.Messages.Disconnect
  alias Hyparview.Messages.Connect

  @behaviour GenStatem

  defmodule Data do
    @moduledoc false

    defstruct view: %View{},
              join_interval: Config.join_interval(),
              join_timeout: Config.join_timeout(),
              shuffle_interval: Config.shuffle_interval(),
              neighbor_interval: Config.neighbor_interval(),
              node: Node.self()

    def new do
      _ = Rand.seed(:exsplus)
      %Data{}
    end
  end

  # API functions

  @spec fanout(MapSet.t(), term()) :: :ok
  def fanout(nodes, msg) do
    :ok =
      nodes
      |> MapSet.delete(Node.self())
      |> Enum.each(&send_message(&1, msg))
  end

  @spec send_message(nil | Node.t(), term()) :: :ok
  def send_message(nil, _msg), do: :ok

  def send_message(node, msg) do
    :ok = Process.send({__MODULE__, node}, msg, [])
  end

  @spec send_message(term()) :: :ok
  def send_message(msg) do
    :ok = Process.send(__MODULE__, msg, [])
  end

  @spec send_after(Node.t(), term(), non_neg_integer()) :: reference()
  def send_after(node, msg, after_msec) do
    _timer_ref = Process.send_after(__MODULE__, {:send_after, node, msg}, after_msec)
  end

  @spec send_after(term(), non_neg_integer()) :: reference()
  def send_after(msg, after_msec) do
    _timer_ref = Process.send_after(__MODULE__, msg, after_msec)
  end

  @spec get_active_view() :: MapSet.t(Node.t()) | {:error, :timeout}
  def get_active_view, do: get_active_view(Node.self())

  @spec get_active_view(Node.t()) :: MapSet.t(Node.t()) | {:error, :timeout}
  def get_active_view(node), do: safe_call(node, {:get, :active})

  @spec get_passive_view() :: MapSet.t(Node.t()) | {:error, :timeout}
  def get_passive_view, do: get_passive_view(Node.self())

  @spec get_passive_view(Node.t()) :: MapSet.t(Node.t()) | {:error, :timeout}
  def get_passive_view(node), do: safe_call(node, {:get, :passive})

  # gen_statem callback functions

  def callback_mode do
    [:state_enter, :handle_event_function]
  end

  def start_link do
    GenStatem.start_link({:local, __MODULE__}, __MODULE__, [], [])
  end

  def init(_args) do
    {:ok, INIT, Data.new()}
  end

  # Handler for common state
  def handle_event({:call, from}, {:get, :active}, _state, data) do
    {:keep_state_and_data, [{:reply, from, data.view.active}]}
  end

  def handle_event({:call, from}, {:get, :passive}, _state, data) do
    {:keep_state_and_data, [{:reply, from, data.view.passive}]}
  end

  def handle_event(:info, {:send_after, _node, %Join{}}, JOINED, _data) do
    # Drop
    :keep_state_and_data
  end

  def handle_event(:info, {:send_after, node, msg}, _state, _data) do
    :ok = send_message(node, msg)
    :keep_state_and_data
  end

  # handler for INIT state
  def handle_event(type, msg, INIT, data) do
    handle_INIT(type, msg, data)
  catch
    _, _ ->
      System.stacktrace()
      |> inspect()
      |> Logger.error()
  end

  # handler for JOINED state
  def handle_event(type, msg, JOINED, data) do
    handle_JOINED(type, msg, data)
  catch
    _, _ ->
      System.stacktrace()
      |> inspect()
      |> Logger.error()
  end

  # handler for unknown state
  def handle_event(type, msg, _state, _data) do
    debug(fn -> "Unhandled message received (type: #{type} msg: #{inspect(msg)})" end)
    :keep_state_and_data
  end

  # private functions

  defp handle_INIT(:enter, _old_state, data) do
    :ok = Join.send!(data.view)

    timeouts = [
      {:state_timeout, 1000, RestartJoin},
      {:state_timeout, 50_000, StartNeighbor}
    ]

    {:keep_state, data, timeouts}
  end

  defp handle_INIT(:state_timeout, RestartJoin, _data) do
    :repeat_state_and_data
  end

  defp handle_INIT(:state_timeout, StartNeighbor, data) do
    :ok = Neighbor.send!(data.view)
    neighbor_timeout = Utils.random_delay(data.neighbor_interval)
    {:keep_state, data, [{:state_timeout, neighbor_timeout, StartNeighbor}]}
  end

  defp handle_INIT(:info, %Join{sender: sender} = join, data) do
    :ok = debug("JOIN request received from #{sender} on #{Node.self()}")
    view = Join.handle(join, data.view)
    {:next_state, JOINED, %{data | view: view}}
  end

  defp handle_INIT(:info, %Neighbor{sender: sender} = neighbor, data) do
    :ok = debug("NEIGHBOR received from #{sender} on #{Node.self()}")
    view = Neighbor.handle(neighbor, data.view)
    {:next_state, %{data | view: view}}
  end

  defp handle_INIT(:info, %NeighborAccepted{sender: sender} = neighbor_accepted, data) do
    :ok = debug("NEIGHBOR ACCEPTED by #{sender} on #{Node.self()}")
    view = NeighborAccepted.handle(neighbor_accepted, data.view)
    {:next_state, JOINED, %{data | view: view}}
  end

  defp handle_INIT(:info, %NeighborRejected{sender: sender} = neighbor_rejected, data) do
    :ok = debug("NEIGHBOR REJECTED by #{sender} on #{Node.self()}")
    view = NeighborRejected.handle(neighbor_rejected, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_INIT(:info, %JoinAccepted{sender: sender} = join_accepted, data) do
    :ok = debug("JOIN accepted by #{sender} on #{Node.self()}")
    view = JoinAccepted.handle(join_accepted, data.view)
    {:next_state, JOINED, %{data | view: view}}
  end

  defp handle_INIT(:info, %JoinFailed{sender: sender} = join_failed, data) do
    :ok = debug("JOIN rejected by #{sender} on #{Node.self()}")
    _tref = JoinFailed.handle(join_failed, data.view)
    :keep_state_and_data
  end

  defp handle_INIT(:info, %ForwardJoin{}, _data) do
    {:keep_state_and_data, [:postpone]}
  end

  defp handle_INIT(:info, %Neighbor{}, _data) do
    {:keep_state_and_data, [:postpone]}
  end

  defp handle_INIT(:info, %Disconnect{}, _data) do
    {:keep_state_and_data, [:postpone]}
  end

  defp handle_INIT(type, msg, _data) do
    :ok =
      debug(fn -> "Unhandled message received (type: #{type} msg: #{inspect(msg)}) on INIT" end)

    :keep_state_and_data
  end

  defp handle_JOINED(:enter, _old, data) do
    shuffle_inval_delay = Utils.random_delay(data.shuffle_interval)
    _ = send_after(StartShuffle, shuffle_inval_delay)
    neigh_inval_delay = Utils.random_delay(data.neighbor_interval)
    _ = send_after(StartNeighbor, neigh_inval_delay)
    :ok = debug("Schedule SHUFFLE after #{shuffle_inval_delay} msec")
    :ok = debug("Schedule NEIGHBOR after #{neigh_inval_delay} msec")
    :keep_state_and_data
  end

  defp handle_JOINED(:info, StartShuffle, data) do
    :ok = Shuffle.send!(data.view)
    shuffle_inval_delay = Utils.random_delay(data.shuffle_interval)
    _ = send_after(StartShuffle, shuffle_inval_delay)
    :ok = debug("Schedule SHUFFLE after #{shuffle_inval_delay} msec")
    :keep_state_and_data
  end

  defp handle_JOINED(:info, StartNeighbor, data) do
    if View.has_free_slot_in_active_view?(data.view) do
      :ok = Neighbor.send!(data.view)
      neigh_inval_delay = Utils.random_delay(data.neighbor_interval)
      _ = send_after(StartNeighbor, neigh_inval_delay)
      :ok = debug("Schedule NEIGHBOR after #{neigh_inval_delay} msec")
    end

    :keep_state_and_data
  end

  defp handle_JOINED(:info, %Connect{sender: sender} = connect, data) do
    :ok = debug("CONNECT by #{sender} on #{Node.self()}")
    view = Connect.handle(connect, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %Join{sender: sender} = join, data) do
    :ok = debug("JOIN request received from #{sender} on #{Node.self()}")
    view = Join.handle(join, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %JoinAccepted{sender: sender} = join_accepted, data) do
    :ok = debug("JOIN accepted by #{sender} on #{Node.self()}")
    view = JoinAccepted.handle(join_accepted, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %ForwardJoin{sender: sender} = forward_join, data) do
    :ok = debug("FORWARDJOIN received from #{sender} on #{Node.self()}")
    {_result, view} = ForwardJoin.handle(forward_join, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %Shuffle{sender: sender} = shuffle, data) do
    :ok = debug("SHUFFLE request received from #{sender} on #{Node.self()}")
    view = Shuffle.handle(shuffle, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %ShuffleReply{sender: sender} = shuffle_reply, data) do
    :ok = debug("SHUFFLEREPLY received from #{sender} on #{Node.self()}")
    view = ShuffleReply.handle(shuffle_reply, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %Neighbor{sender: sender} = neighbor, data) do
    :ok = debug("NEIGHBOR received from #{sender} on #{Node.self()}")
    view = Neighbor.handle(neighbor, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %NeighborAccepted{sender: sender} = neighbor_accepted, data) do
    :ok = debug("NEIGHBOR ACCEPTED by #{sender} on #{Node.self()}")
    view = NeighborAccepted.handle(neighbor_accepted, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %NeighborRejected{sender: sender} = neighbor_rejected, data) do
    :ok = debug("NEIGHBOR REJECTED by #{sender} on #{Node.self()}")
    view = NeighborRejected.handle(neighbor_rejected, data.view)
    {:keep_state, %{data | view: view}}
  end

  defp handle_JOINED(:info, %Disconnect{sender: sender} = disconnect, data) do
    :ok = debug("DISCONNECTED #{sender} on #{Node.self()}")
    view = Disconnect.handle(disconnect, data.view)
    {:repeat_state, %{data | view: view}}
  end

  defp handle_JOINED(type, msg, _data) do
    debug(fn -> "Unhandled message received (type: #{type} msg: #{inspect(msg)}) on JOINED" end)
    :keep_state_and_data
  end

  @call_timeout 1000

  @spec safe_call(Node.t(), term()) :: MapSet.t(Node.t()) | {:error, :timeout}
  defp safe_call(node, msg) do
    GenStatem.call({__MODULE__, node}, msg, @call_timeout)
  catch
    :exit, _ ->
      {:error, :timeout}
  end
end
