use Mix.Config

config :redix_cluster,
  cluster_nodes: [%{host: '10.1.2.7', port: 7000},
                  %{host: '10.1.2.6', port: 7000},
                  %{host: '10.1.2.5', port: 7000}
                 ],
  pool_size: 5,
  pool_max_overflow: 0,

# connection_opts
  socket_opts: [],
  backoff_initial: 1000,
  backoff_max: :infinity
