# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :hyparview,
  contact_nodes: [:"node1@127.0.0.1", :"node2@127.0.0.1", :"node3@127.0.0.1", :"node4@127.0.0.1"],
  active_view_size: 8,
  handler_module: Hyparview.ExampleHandler

config :logger, :console,
  colors: [enabled: true],
  level: :debug,
  format: "$time [$level] [$metadata] $levelpad$message\n",
  metadata: [:module]
