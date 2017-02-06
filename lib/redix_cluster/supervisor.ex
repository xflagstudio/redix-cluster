defmodule RedixCluster.Supervisor do
  @moduledoc false

  import Supervisor.Spec

  @spec start_link() :: Supervisor.on_start
  def start_link() do
    children = [
      supervisor(RedixCluster.Pools.Supervisor, [[name: RedixCluster.Pools.Supervisor]], [modules: :dynamic]),
      worker(RedixCluster.Monitor, [[name: RedixCluster.Monitor]], [modules: :dynamic])
    ]

    slot_cache_num = RedixCluster.SlotCache.process_num()
    slot_cache_worker = Enum.map(1..slot_cache_num, fn(x) ->
      name = RedixCluster.SlotCache.process_name(x)
      worker(RedixCluster.SlotCache, [name], [id: name])
    end)

    Supervisor.start_link(children ++ slot_cache_worker, strategy: :one_for_one, name: __MODULE__)
  end

end
