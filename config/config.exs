# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :hyparview,
  contact_nodes: [:"node3@shun159", :"node10@shun159", :"node20@shun159"],
  active_view_size: 4,
  callback_module: Hyparview.DefaultHandler

config :logger, :console,
  colors: [enabled: true],
  level: :error,
  format: "$time [$level] [$metadata] $levelpad$message\n",
  metadata: [:module]
