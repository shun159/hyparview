import Config

config :hyparview,
  contact_nodes: [
  ]

config :aten,
  poll_interval: 1000

config :logger,
  level: :debug,
  format: "$date $time [$level] $message\n",
  metadata: [],
  handle_otp_reports: true
