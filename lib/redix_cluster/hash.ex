defmodule RedixCluster.Hash do
  @moduledoc false

  @redis_cluster_hash_slots 16384

  ## CRCBench
  # benchmark name   iterations   average time 
  # CRC                     100   20819.58 µs/op
  # RedixClusterCRC          10   126367.30 µs/op

  @spec hash(binary) :: integer
  def hash(key) when is_list(key), do: key |> to_string |> hash
  def hash(key), do: CRC.ccitt_16_xmodem(key) |>rem @redis_cluster_hash_slots

end
