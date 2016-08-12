use Mix.Config

config :redix_cluster,
  cluster_nodes: [%{host: '127.0.0.1', port: 7000},
                  %{host: '127.0.0.1', port: 7001},
                  %{host: '127.0.0.1', port: 7002}
                 ],
  pool_size: 5,
  pool_max_overflow: 0,

# connection_opts
  socket_opts: [],
  backoff: 2000,
  max_reconnection_attempts: nil

