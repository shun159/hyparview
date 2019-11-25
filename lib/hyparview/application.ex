defmodule Hyparview.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Hyparview.Supervisor.start_link()
  end
end
