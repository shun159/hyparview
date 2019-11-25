import Config

config :hyparview,
  contact_nodes: [
    :"node1@127.0.0.1",
    :"node2@127.0.0.1",
    :"node3@127.0.0.1"
  ]

config :aten,
  poll_interval: 1000

config :logger,
  level: :debug,
  format: "$date $time [$level] $message\n",
  metadata: [],
  handle_otp_reports: true
