defmodule Hyparview.Config do
  @moduledoc """
  Configuration Utils
  """

  @c 3
  @k 6
  @log_total_members 4
  @default_active_view_size @log_total_members + @c
  @default_passive_view_size @k * (@log_total_members + @c)
  @default_shuffle_interval 60 * 1000

  @spec contact_nodes() :: MapSet.t(Node.t())
  def contact_nodes do
    :contact_nodes
    |> get_env(Node.list())
    |> MapSet.new()
    |> MapSet.delete(Node.self())
  end

  @spec active_random_walk_length() :: non_neg_integer()
  def active_random_walk_length, do: get_env(:active_random_walk_length, 8)

  @spec passive_random_walk_length() :: non_neg_integer()
  def passive_random_walk_length, do: get_env(:passive_random_walk_length, 5)

  @spec join_timeout() :: non_neg_integer()
  def join_timeout, do: get_env(:join_timeout, 1000)

  @spec except_nodes() :: [Node.t()]
  def except_nodes, do: get_env(:except_nodes, [])

  @spec active_view_size() :: non_neg_integer()
  def active_view_size, do: get_env(:active_view_size, @default_active_view_size)

  @spec passive_view_size() :: non_neg_integer()
  def passive_view_size, do: get_env(:passive_view_size, @default_passive_view_size)

  @spec neighbor_interval() :: non_neg_integer()
  def neighbor_interval, do: get_env(:neighbor_interval, 10_000)

  @spec join_interval() :: non_neg_integer()
  def join_interval, do: get_env(:join_interval, 1_000)

  @spec shuffle_interval() :: non_neg_integer()
  def shuffle_interval, do: get_env(:shuffle_interval, @default_shuffle_interval)

  @spec callback_module() :: atom()
  def callback_module, do: get_env(:callback_module, Hyparview.DefaultHandler)

  # private functions

  defp get_env(key, default), do: Application.get_env(:hyparview, key, default)
end
