defmodule Hyparview do
  @moduledoc false

  def get_active_view,
    do: GenServer.call(Hyparview.Membership, :get_active_view)

  def get_active_view(node),
    do: GenServer.call({Hyparview.Membership, node}, :get_active_view)

  def get_passive_view,
    do: GenServer.call(Hyparview.Membership, :get_passive_view)

  def get_passive_view(node),
    do: GenServer.call({Hyparview.Membership, node}, :get_passive_view)

  def subscribe,
    do: GenServer.cast(Hyparview.Membership, {:subscribe, self()})
end
