defmodule Hyparview.EventHandler do
  @moduledoc """
  Hyparview Event handler
  """

  use GenServer

  alias Hyparview.Config
  alias Hyparview.View

  defmodule State do
    @moduledoc false

    defstruct [
      cb_mod: Config.callback_module(),
      cb_state: nil
    ]
  end

  @spec joining() :: :ok
  def joining do
    :ok = GenServer.cast(__MODULE__, :joining)
  end

  @spec joined(View.t()) :: :ok
  def joined(view) do
    :ok = GenServer.cast(__MODULE__, {:joined, view})
  end

  @spec add_node(Node.t(), View.t()) :: :ok
  def add_node(node, view) do
    :ok = GenServer.cast(__MODULE__, {:add_node, node, view})
  end

  @spec del_node(Node.t(), View.t()) :: :ok
  def del_node(node, view) do
    :ok = GenServer.cast(__MODULE__, {:del_node, node, view})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def handle_cast(:joining, %State{cb_mod: cb_mod} = state) do
    {:ok, cb_state} = cb_mod.joining()
    {:noreply, %{state | cb_state: cb_state}}
  end
  def handle_cast({:joined, view}, %State{cb_mod: cb_mod} = state) do
    {:ok, cb_state} = cb_mod.joined(view, state.cb_state)
    {:noreply, %{state | cb_state: cb_state}}
  end
  def handle_cast({:add_node, node, view}, %State{cb_mod: cb_mod} = state) do
    {:ok, cb_state} = cb_mod.add_node(node, view, state.cb_state)
    {:noreply, %{state | cb_state: cb_state}}
  end
  def handle_cast({:del_node, node, view}, %State{cb_mod: cb_mod} = state) do
    {:ok, cb_state} = cb_mod.del_node(node, view, state.cb_state)
    {:noreply, %{state | cb_state: cb_state}}
  end
end
