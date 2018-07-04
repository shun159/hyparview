defmodule Hyparview.Messages.Shuffle do
  @moduledoc """
  SHUFFLE request abstraction module
  """

  alias __MODULE__
  alias Hyparview.Config
  alias Hyparview.Utils
  alias Hyparview.View
  alias Hyparview.PeerManager
  alias Hyparview.Messages.ShuffleReply

  defstruct sender: Node.self(),
            origin: Node.self(),
            nodes: MapSet.new(),
            ttl: Config.active_random_walk_length()

  @type t :: %Shuffle{
          sender: Node.t(),
          origin: Node.t(),
          nodes: MapSet.t(Node.t()),
          ttl: non_neg_integer()
        }

  @typep new_options :: [
           sender: Node.t(),
           origin: Node.t(),
           view: View.t(),
           ttl: non_neg_integer()
         ]

  @doc """
  Make a SHUFFLE message that includes `nodes` that active_view

      shuffle = Shuffle.new(view: view)
  """
  @spec new(new_options()) :: Shuffle.t()
  def new(options \\ []) do
    %Shuffle{
      sender: options[:sender] || Node.self(),
      origin: options[:origin] || Node.self(),
      nodes: to_nodes(options[:view]),
      ttl: options[:ttl] || Config.active_random_walk_length()
    }
  end

  @doc """
  Send a `list` in a Shuffle request to a random neighbor of its active view.
  list contains;
    - p’s own identifier
    - Ka nodes from its active view
    - Kp nodes from its passive view

      :ok = Shuffle.send!(shuffle, view)
  """
  @spec send!(View.t()) :: :ok
  def send!(%View{active: active} = view) do
    active
    |> Utils.choose_node()
    |> PeerManager.send_message(new(view: view))
  end

  @spec send_after(View.t()) :: reference()
  def send_after(%View{active: active} = view) do
    base_time = Config.shuffle_interval()
    after_msec = Utils.random_delay(base_time)

    active
    |> Utils.choose_node()
    |> PeerManager.send_after(new(view: view), after_msec)
  end

  @doc """
      if Shuffle.should_forward?(shuffle, view) do
        :ok = Shuffle.forward!(shuffle, view)
      else
        :ok = ShuffleReply.new(passive: passive, shuffle: shuffle)
        |> ShuffleReply.send!(shuffle.sender)
      end
  """
  @spec should_forward?(t(), View.t()) :: boolean()
  def should_forward?(%Shuffle{ttl: 0}, _view), do: false

  def should_forward?(%Shuffle{}, %View{} = view) do
    view.active
    |> MapSet.size()
    |> Kernel.>(1)
  end

  @doc """
      %View{} = Shuffle.handle(shuffle, state.view)
  """
  @spec handle(t(), View.t()) :: View.t()
  def handle(shuffle, view0) do
    if should_forward?(shuffle, view0),
      do: forward!(shuffle, view0),
      else: send_shuffle_reply(view0, shuffle)
  end

  @doc """
  If the time to live of the message is greater than zero and the number of nodes
  in q’s active view is greater than 1, the node will select a random node
  from its active view, different from the one he received this shuffle message from,
  and simply forwards the Shuffle request.
  """
  @spec forward!(t(), View.t()) :: View.t()
  def forward!(%Shuffle{} = shuffle, %View{} = view) do
    :ok =
      view.active
      |> exclude_sender_and_origin(shuffle)
      |> Utils.choose_node()
      |> PeerManager.send_message(%{shuffle | ttl: shuffle.ttl - 1, sender: Node.self()})

    view
  end

  # private functions

  @spec exclude_sender_and_origin(MapSet.t(), t()) :: MapSet.t(Node.t())
  defp exclude_sender_and_origin(active, shuffle) do
    active
    |> Enum.filter(&without_sender_and_origin(&1, shuffle))
    |> MapSet.new()
  end

  @spec without_sender_and_origin(Node.t(), t()) :: boolean()
  defp without_sender_and_origin(node, %Shuffle{sender: sender, origin: origin}),
    do: not (node in [sender, origin])

  @spec to_nodes(View.t()) :: MapSet.t(Node.t())
  defp to_nodes(%View{active: active, passive: passive}) do
    active
    |> MapSet.union(passive)
  end

  @spec send_shuffle_reply(View.t(), t()) :: View.t()
  defp send_shuffle_reply(view0, shuffle) do
    view = View.trim_and_add_to_passive(view0, shuffle.nodes)

    [view: view, shuffle: shuffle]
    |> ShuffleReply.new()
    |> ShuffleReply.send!(shuffle.sender)

    view
  end
end
