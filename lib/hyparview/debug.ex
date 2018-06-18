defmodule Hyparview.Debug do
  @moduledoc false

  # borrowed from sile/evel

  @spec slave_start_n(non_neg_integer()) :: :ok
  def slave_start_n(count),
    do: slave_start_n(1, count)

  @spec slave_start_n(non_neg_integer(), non_neg_integer()) :: :ok
  def slave_start_n(min, max),
    do: slave_start_n_iml(min, max, :start)

  @spec slave_start_link_n(non_neg_integer()) :: :ok
  def slave_start_link_n(count),
    do: slave_start_link_n(1, count)

  @spec slave_start_link_n(non_neg_integer(), non_neg_integer()) :: :ok
  def slave_start_link_n(min, max),
    do: slave_start_n_iml(min, max, :start_link)

  # private functions

  @spec slave_start_n_iml(non_neg_integer(), non_neg_integer(), atom()) :: :ok
  defp slave_start_n_iml(min, max, start_fn) do
    {:ok, host} = :inet.gethostname()
    :ok = start_slaves(host, min, max, start_fn)
    :ok = load_paths_on_slave()
    :ok = start_applications()
  end

  @spec start_slaves(charlist(), non_neg_integer(), non_neg_integer(), atom()) :: :ok
  defp start_slaves(host, min, max, start_fn) do
    min
    |> Range.new(max)
    |> Enum.each(&start_slave(&1, host, start_fn))
  end

  @spec load_paths_on_slave() :: :ok
  defp load_paths_on_slave do
    :rpc.multicall(:code, :add_pathsa, [:code.get_path()])
    :rpc.multicall(:code, :add_patha, [:code.lib_dir(:compiler, :ebin)])
    :rpc.multicall(:code, :add_patha, [:code.lib_dir(:elixir, :ebin)])
    :rpc.multicall(:code, :add_patha, [:code.lib_dir(:hyparview, :ebin)])
    :ok
  end

  @spec start_applications() :: :ok
  defp start_applications do
    :rpc.eval_everywhere(:application, :ensure_all_started, [:elixir])
    :rpc.eval_everywhere(Application, :ensure_all_started, [:hyparview])
    :ok
  end

  defp start_slave(n, host, fun),
    do: {:ok, _} = apply(:slave, fun, [host, to_charlist(n)])
end
