defmodule RedixCluster.Worker do
  @moduledoc """
    role: poolboy worker
  """
  use GenServer
  use RedixCluster.Helper

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def init(worker) do
   socket_opts = get_env(:socket_opts, [])
   backoff_initial = get_env(:backoff_initial, 1000)
   backoff_max = get_env(:backoff_max, :infinity)
   :erlang.process_flag(:trap_exit, true)
   RedixCluster.Pools.Supervisor.register_worker_connection(worker[:pool_name])
   result =
     Redix.start_link(
       host: worker[:host],
       port: worker[:port],
       socket_opts: socket_opts,
       backoff_initial: backoff_initial,
       backoff_max: backoff_max
     )

   :erlang.process_flag(:trap_exit, false)
   case result do
     {:ok, connection} -> {:ok, %{conn: connection}}
      _ -> {:ok, %{conn: :no_connection}}
   end
  end

  def handle_call({_, _, _}, _from, %{conn: :no_connection} = state) do
    {:reply, {:error, :no_connection}, state}
  end
  def handle_call({:command, params, opts}, _From, %{conn: conn} = state) do
    try do
      {:reply, Redix.command(conn, params, opts), state}
    rescue
      e in Redix.Error ->
        {:reply, {:error, e}, state}
    end
  end
  def handle_call({:pipeline, params, opts}, _from, %{conn: conn} = state) do
    try do
      {:reply, Redix.pipeline(conn, params, opts), state}
    rescue
      e in Redix.Error ->
        {:reply, {:error, e}, state}
    end
  end
  def handle_call(_request, _from, state), do: {:reply, :ok, state}

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_info(_request, state), do: {:noreply, state}

  def terminate(_reason, %{conn: :no_connection}), do: :ok
  def terminate(_reason, %{conn: conn}), do: Redix.stop(conn)

end
