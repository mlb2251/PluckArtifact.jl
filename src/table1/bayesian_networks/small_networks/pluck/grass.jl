# Classic example from Judea Pearl's Causality book
# Adapted from https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/grass.dice


grass_example = """
(let (cloudy (flip 0.5)
      rain (flip (if cloudy 0.8 0.2))
      sprinkler (flip (if cloudy 0.1 0.5))
      temp1 (flip 0.7)
      wetRoof (and temp1 rain)
      temp2 (flip 0.9)
      temp3 (flip 0.9)
      wetGrass (or (and temp2 rain) (and temp3 sprinkler)))
  (given wetGrass rain)
)
"""

add_benchmark!("grass", "pluck_default", PluckBenchmark(grass_example; kwargs=Dict(:normalize => true)))
