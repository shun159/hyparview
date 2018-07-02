defmodule Hyparview.EventHandler do
  @moduledoc """
  Hyparview Event handler
  """

  use GenServer, restart: :parmanent

  alias Hyparview.Config
  alias Hyparview.View

  defmodule State do
    @moduledoc false

    defstruct cb_mod: Config.callback_module()
  end

  @spec add_node(Node.t(), View.t()) :: :ok
  def add_node(remote_node, view) do
    :ok = GenServer.cast(__MODULE__, {:add_node, remote_node, view})
  end

  @spec del_node(Node.t(), View.t()) :: :ok
  def del_node(remote_node, view) do
    :ok = GenServer.cast(__MODULE__, {:del_node, remote_node, view})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def handle_cast({:add_node, remote_node, view}, %State{cb_mod: cb_mod} = state) do
    if MapSet.member?(view.active, remote_node), do: cb_mod.add_node(remote_node, view)
    {:noreply, state}
  end

  def handle_cast({:del_node, remote_node, view}, %State{cb_mod: cb_mod} = state) do
    unless MapSet.member?(view.active, remote_node), do: cb_mod.del_node(remote_node, view)
    {:noreply, state}
  end
end
