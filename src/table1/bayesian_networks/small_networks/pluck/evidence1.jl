# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/evidence1.dice
# let evidence = flip 0.5 in
#     let coin  = flip 0.5 in
#     if evidence then
#         let tmp = observe coin in evidence
#         else evidence

evidence1_example = """
(let (evidence (flip 0.5)
    coin (flip 0.5))
    (if evidence (given coin evidence) evidence)
)
"""

add_benchmark!("evidence1", "pluck_default", PluckBenchmark(evidence1_example; normalize=true))