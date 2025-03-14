# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/evidence2.dice
# let evidence = flip 0.5 in
#     if evidence then
#         let coin1  = flip 0.5 in
#         let tmp = observe coin1 in
#         coin1
#     else
#         flip 0.5

evidence2_example = """
(let (evidence (flip 0.5))
    (if evidence
        (let (coin1 (flip 0.5))
            (given coin1 coin1)
        )
        (flip 0.5)
    )
)
"""

add_benchmark!("evidence2", "pluck_default", PluckBenchmark(evidence2_example; kwargs=Dict(:normalize => true)))

