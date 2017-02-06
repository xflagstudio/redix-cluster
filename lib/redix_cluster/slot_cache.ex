defmodule RedixCluster.SlotCache do
  @moduledoc false

  use GenServer
  use RedixCluster.Helper

  def process_num do
    get_env(:worker_num, 2) * 2
  end

  def process_name(num) do
    Module.concat(__MODULE__, Integer.to_string(num))
  end

  def refresh_mapping(version) do
    Enum.each(1..process_num(), fn(x) ->
      target_process = process_name(x)
      GenServer.call(target_process, {:reload_slots_map, version})
    end)
  end

  def get_pool({:error, _} = error), do: error
  def get_pool(slot) do
    target_process = process_name(Enum.random(1..process_num()))
    GenServer.call(target_process, {:get_pool, slot})
  end

  ### for spec
  def get_slot_maps() do
    target_process = process_name(Enum.random(1..process_num()))
    GenServer.call(target_process, {:get_slot_maps})
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, nil, [name: name])
  end

  def init(nil) do
    {:ok, RedixCluster.Monitor.get_slot_cache}
  end

  def handle_call({:get_pool, slot}, _from, state) do
    case state.is_cluster do
      true  ->
        {:reply, {state.version, get_pool_by_slot(slot, state.slots_maps, state.slots)}, state}
      false ->
        [slots_map] = state.slots_maps
        {:reply, {state.version, slots_map.node.pool}, state}
    end
  end

  def handle_call({:reload_slots_map, version}, _from, _state = %RedixCluster.Monitor.State{version: version}) do
    {:reply, :ok, RedixCluster.Monitor.get_slot_cache}
  end
  def handle_call({:reload_slots_map, version}, _from, state = %RedixCluster.Monitor.State{version: old_version}) do
    {:reply, {:ingore, "wrong version#{version}!=#{old_version}"}, state}
  end

  def handle_call({:get_slot_maps}, _from, state) do
    {:reply, {state.version, state.slots_maps}, state}
  end

  def handle_call(request, _from, state), do: {:reply, {:ignored, request}, state}
  def handle_cast(_msg, state), do: {:noreply, state}
  def handle_info(_info, state), do: {:noreply, state}

  defp get_pool_by_slot(slot, slots_maps, slots) do
    index = Enum.at(slots, slot)
    cluster = Enum.at(slots_maps, index - 1)
    case cluster == nil or cluster.node == nil do
      true  -> nil
      false -> cluster.node.pool
    end
  end

end
