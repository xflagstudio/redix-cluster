defmodule ParseSlotsMap.Spec do

  use ESpec

  @cluster_info [[10923, 16383, ["Host1", 7000, "hashhash"], ["SlaveHost1", 7001, "hashhashaaa"]],
                  [5461, 10922, ["Host2", 7000, "hash"]],
                  [0, 5460, ["Host3", 7000, "haahaha"], ["SlaveHost3", 7001, "aaaa"]]]

  it  do
    RedixCluster.Monitor.parse_slots_maps(@cluster_info) |> to eq [
      %{start_slot: 10923, end_slot: 16383, index: 1, name: :"10923:16383", node: %{host: "Host1", pool: nil, port: 7000}},
      %{start_slot: 5461, end_slot: 10922, index: 2, name: :"5461:10922", node: %{host: "Host2", pool: nil, port: 7000}},
      %{start_slot: 0, end_slot: 5460, index: 3, name: :"0:5460", node: %{host: "Host3", pool: nil, port: 7000}}]
  end

 end
