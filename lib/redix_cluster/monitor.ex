defmodule RedixCluster.Monitor do
  @moduledoc false

  use GenServer
  use RedixCluster.Helper

  @redis_cluster_hash_slots 16384

  defmodule State, do: defstruct cluster_nodes: [], slots: [], slots_maps: [], version: 0, is_cluster: true

  @spec connect(term) :: :ok | {:error, :connect_to_empty_nodes}
  def connect([]), do: {:error, :connect_to_empty_nodes}
  def connect(cluster_nodes), do: GenServer.call(__MODULE__, {:connect, cluster_nodes})

  @spec refresh_mapping(integer) :: :ok | {:ignore, String.t}
  def refresh_mapping(version) do
    result = GenServer.call(__MODULE__, {:reload_slots_map, version})
    RedixCluster.SlotCache.refresh_mapping(version)
    result
  end

  def get_slot_cache() do
    GenServer.call(__MODULE__, {:get_slot})
  end

  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options), do: GenServer.start_link(__MODULE__, nil, options)

  def init(nil) do
    case get_env(:cluster_nodes, []) do
      [] -> {:ok, %State{}}
      cluster_nodes -> {:ok, do_connect(cluster_nodes)}
    end
  end

  def handle_call({:get_slot}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:reload_slots_map, version}, _from, state = %State{version: version}) do
    {:reply, :ok, reload_slots_map(state)}
  end
  def handle_call({:reload_slots_map, version}, _from, state = %State{version: old_version}) do
    {:reply, {:ingore, "wrong version#{version}!=#{old_version}"}, state}
  end
  def handle_call({:connect, cluster_nodes}, _from, _state), do: {:reply, :ok, do_connect(cluster_nodes)}
  def handle_call(request, _from, state), do: {:reply, {:ignored, request}, state}

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_info(_info, state), do: {:noreply, state}

  defp do_connect(cluster_nodes) do
    %State{cluster_nodes: cluster_nodes}
      |> reload_slots_map
  end

  defp reload_slots_map(state) do
    old_slots_maps = state.slots_maps
    {is_cluster, cluster_info} = get_cluster_info(state.cluster_nodes)
    slots_maps = cluster_info |> parse_slots_maps |> connect_all_slots
    slots = create_slots_cache(slots_maps)

    # close only removed pool
    removed = removed_nodes(old_slots_maps, slots_maps)
    for slots_map <- removed, do: close_connection(slots_map)

    %State{state | slots: slots, slots_maps: slots_maps, version: state.version + 1, is_cluster: is_cluster}
  end

  defp removed_nodes(old_slots_maps, slots_maps) do
    new_pools = slots_maps |> Enum.map(fn(slot) -> slot.node.pool end)
    old_slots_maps |> Enum.reject(fn(slot) -> slot.node.pool in new_pools end)
  end

  defp close_connection(slots_map) do
    try do
      RedixCluster.Pools.Supervisor.stop_redis_pool(slots_map.node.pool)
    catch
      _ -> :ok
    end
  end

  defp get_cluster_info([]), do: throw({:error, :cannot_connect_to_cluster})
  defp get_cluster_info([node|restnodes]) do
    case start_link_redix(node.host, node.port) do
      {:ok, conn} ->
        case Redix.command(conn, ~w(CLUSTER SLOTS), []) do
          {:ok, cluster_info} ->
            Redix.stop(conn)
            {true, cluster_info}

          {:error, %Redix.Error{}} ->
            cluster_info_from_single_node(node)

          {:error, _} ->
            get_cluster_info(restnodes)
        end

      _ ->
        get_cluster_info(restnodes)
    end
  end

  #[[10923, 16383, ["Host1", 7000], ["SlaveHost1", 7001]],
  #[5461, 10922, ["Host2", 7000], ["SlaveHost2", 7001]],
  #[0, 5460, ["Host3", 7000], ["SlaveHost3", 7001]]]
  def parse_slots_maps(cluster_info) do
    cluster_info
      |> Stream.with_index
      |> Stream.map(&parse_cluster_slot/1)
      |> Enum.to_list
  end

  defp connect_all_slots(slots_maps) do
    for slot <-slots_maps, do: %{slot | node: connect_node(slot.node)}
  end

  defp create_slots_cache(slots_maps) do
    for slots_map <- slots_maps do
      for index <- slots_map.start_slot..slots_map.end_slot, do: {index, slots_map.index}
    end
      |> List.flatten
      |> List.keysort(0)
      |> Enum.map(fn({_index, index}) -> index end)
  end

  def start_link_redix(host, port) do
    socket_opts = get_env(:socket_opts, [])
    backoff_initial = get_env(:backoff_initial, 1000)
    backoff_max = get_env(:backoff_max, :infinity)
    :erlang.process_flag(:trap_exit, true)

    result =
      Redix.start_link(
        host: host,
        port: port,
        socket_opts: socket_opts,
        backoff_initial: backoff_initial,
        backoff_max: backoff_max
      )

    :erlang.process_flag(:trap_exit, false)
    result
  end

  defp cluster_info_from_single_node(node) do
    {false,
      [[0,
        @redis_cluster_hash_slots - 1,
        [node.host, node.port]
      ]]
    }
  end

  defp parse_cluster_slot({cluster_slot, index}) do
    [start_slot, end_slot|nodes] = cluster_slot
    %{index: index + 1,
      name: get_slot_name(start_slot, end_slot),
      start_slot: start_slot,
      end_slot: end_slot,
      node: parse_master_node(nodes)
     }
  end

  defp connect_node(node) do
    case RedixCluster.Pools.Supervisor.new_pool(node.host, node.port) do
      {:ok, pool_name} -> %{node |pool: pool_name}
      _ -> nil
    end
  end

  defp get_slot_name(start_slot, end_slot) do
    [start_slot, ":", end_slot]
      |> Enum.join
      |> String.to_atom
  end

  defp parse_master_node([[master_host, master_port|_]|_]) do
    %{host: master_host,
      port: master_port,
      pool: nil
     }
  end
end
