defmodule Hyparview.Event do
  @moduledoc """
  A behaviour module for HyParView event handler
  """

  alias Hyparview.View

  @doc """
  Invoked when added the node to active view
  """
  @callback add_node(Node.t(), View.t()) :: term()

  @doc """
  Invoked when deleted the node to active view
  """
  @callback del_node(Node.t(), View.t()) :: term()
end
