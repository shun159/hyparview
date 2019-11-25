defmodule Hyparview.Messages do
  @moduledoc false

  @type join_t :: %{
          msg: :join,
          sender: Node.t(),
          tref: reference()
        }

  @type join_ack_t :: %{
          msg: :join_ack,
          sender: Node.t(),
          tref: reference(),
          active: MapSet.t(Node.t())
        }

  @type forward_join_t :: %{
          msg: :forward_join,
          sender: Node.t(),
          new_node: Node.t(),
          ttl: non_neg_integer(),
          prwl: non_neg_integer(),
          adv_path: MapSet.t(Node.t())
        }

  @type neighbor_t :: %{
          msg: :neighbor,
          sender: Node.t(),
          priority: :low | :high
        }

  @type neighbor_ack_t :: %{
          msg: :neighbor_ack,
          sender: Node.t()
        }

  @type neighbor_nak_t :: %{
          msg: :neighbor_nak,
          sender: Node.t(),
          passive_view: MapSet.t(Node.t())
        }

  @type shuffle_t :: %{
          msg: :shuffle,
          sender: Node.t(),
          origin: Node.t(),
          ttl: non_neg_integer(),
          passive_view: MapSet.t(Node.t()),
          active_view: MapSet.t(Node.t()),
          adv_path: MapSet.t(Node.t())
        }

  @type shuffle_reply_t :: %{
          msg: :shuffle_reply,
          sender: Node.t(),
          combined_view: MapSet.t(Node.t())
        }

  @type disconnect_t :: %{
          msg: :disconnect,
          sender: Node.t()
        }

  @type t ::
          join_t
          | join_ack_t
          | forward_join_t
          | neighbor_t
          | neighbor_ack_t
          | neighbor_nak_t
          | shuffle_t
          | shuffle_reply_t
          | disconnect_t

  @spec join(reference) :: join_t
  def join(tref) do
    %{
      msg: :join,
      sender: Node.self(),
      tref: tref
    }
  end

  @spec join_ack(reference, passive_view :: MapSet.t(Node.t())) :: join_ack_t
  def join_ack(tref, passive_view) do
    %{
      msg: :join_ack,
      sender: Node.self(),
      tref: tref,
      passive_view: passive_view
    }
  end

  @spec forward_join(Keyword.t()) :: forward_join_t
  def forward_join(options) do
    %{
      msg: :forward_join,
      sender: Node.self(),
      new_node: options[:new_node],
      ttl: options[:ttl],
      path: options[:path]
    }
  end

  @spec neighbor(:low | :high) :: neighbor_t
  def neighbor(prio) do
    %{
      msg: :neighbor,
      sender: Node.self(),
      priority: prio
    }
  end

  @spec neighbor_ack() :: neighbor_ack_t
  def neighbor_ack do
    %{
      msg: :neighbor_ack,
      sender: Node.self()
    }
  end

  @spec neighbor_nak(MapSet.t(Node.t())) :: neighbor_nak_t
  def neighbor_nak(passive_view) do
    %{
      msg: :neighbor_nak,
      sender: Node.self(),
      passive_view: passive_view
    }
  end

  @spec disconnect() :: disconnect_t
  def disconnect do
    %{
      msg: :disconnect,
      sender: Node.self()
    }
  end

  @spec shuffle(Keyword.t()) :: shuffle_t
  def shuffle(options) do
    %{
      msg: :shuffle,
      sender: Node.self(),
      passive_view: options[:passive_view],
      active_view: options[:active_view],
      ttl: options[:ttl],
      path: options[:path]
    }
  end

  @spec shuffle_reply(combined_view :: MapSet.t(Node.t())) :: shuffle_reply_t
  def shuffle_reply(combined_view) do
    %{
      msg: :shuffle_reply,
      sender: Node.self(),
      combined_view: combined_view
    }
  end
end
