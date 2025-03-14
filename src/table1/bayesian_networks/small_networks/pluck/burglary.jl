# Classic example from Judea Pearl's Causality book

# Also adapted from https://github.com/SHoltzen/dice/blob/master/benchmarks/baselines/alarm.psi

burglary_example = """
(let (earthquake   (flip 0.0001)
      burglary     (flip 0.001)
      alarm        (or earthquake burglary)
      phoneWorking (flip (if earthquake 0.7 0.99))
      maryWakes    (flip (if alarm (if earthquake 0.8 0.6) 0.2))
      called       (and maryWakes phoneWorking))
    (given called burglary)
)
"""

add_benchmark!("burglary", "pluck_default", PluckBenchmark(burglary_example; kwargs=Dict(:normalize => true)))