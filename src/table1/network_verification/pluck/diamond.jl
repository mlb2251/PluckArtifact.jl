# Based on diamond network example from the Dice paper,
# and on https://github.com/Tractables/Dice.jl/blob/d5101ce2b0d0c7a25b0a56973144430d892dc773/examples/examples-old/hoisting_flip_order_experiments/network_verification.jl

function diamond_defs()
  @define "diamond" """
  (λ s1 ->
    (let (route (flip 0.5)
          drop  (flip 0.0001))
      (and (or (not drop) route) s1)))
  """

  @define "diamond_network" """
  (Y (λ network n ->
    (case n of
      O => true | 
      S m => (diamond (network m)))))
  """
end

add_benchmark!("diamond", "pluck_default", PluckBenchmark("(diamond_network 100)"; pre=diamond_defs))
add_benchmark!("diamond", "pluck_strict_enum", PluckBenchmark("(diamond_network 100)"; pre=diamond_defs, skip=true))
add_benchmark!("diamond", "pluck_lazy_enum", PluckBenchmark("(diamond_network 100)"; pre=diamond_defs, skip=true))
