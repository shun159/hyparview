# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :hyparview,
  contact_nodes: [
    :node1@shun159,
    :node2@shun159,
    :node3@shun159,
    :node4@shun159,
    :node5@shun159,
    :node6@shun159,
    :node7@shun159,
    :node8@shun159,
    :node9@shun159
  ],
  callback_module: Hyparview.DefaultHandler

config :logger, :console,
  colors: [enabled: true],
  level: :info,
  format: "$time [$level] [$metadata] $levelpad$message\n",
  metadata: [:module]
