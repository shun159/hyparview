# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :hyparview,
  contact_nodes: [:"1@shun159", :"2@shun159", :"3@shun159", :"4@shun159", :"node1@shun159"],
  active_view_size: 8,
  handler_module: Hyparview.ExampleHandler

config :logger, :console,
  colors: [enabled: true],
  level: :debug,
  format: "$time [$level] [$metadata] $levelpad$message\n",
  metadata: [:module]
