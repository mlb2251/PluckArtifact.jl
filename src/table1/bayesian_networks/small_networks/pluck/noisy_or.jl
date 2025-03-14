# Adapted from https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/noisyOr.dice

noisy_or_example = """
(let (n0 (flip 0.5)
      n4 (flip 0.5)
      n1 (flip (if n0 0.8 0.1))
      n21 (flip (if n0 0.8 0.1))
      n22 (flip (if n4 0.8 0.1))
      n33 (flip (if n4 0.8 0.1))
      n2 (or n21 n22)
      n31 (flip (if n1 0.8 0.1))
      n32 (flip (if n2 0.8 0.1))
      n3 (or n31 (or n32 n33)))
    n3
)
"""

add_benchmark!("noisy_or", "pluck_default", PluckBenchmark(noisy_or_example; kwargs=Dict(:normalize => true)))
