# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/twocoins.dice
# let firstCoin  = flip 0.5 in 
#     let secondCoin  = flip 0.5 in
#     let bothHeads  = (firstCoin && secondCoin) in
#     let tmp = observe !bothHeads in
#     firstCoin

two_coins_example = """
(let (firstCoin (flip 0.5)
        secondCoin (flip 0.5)
    bothHeads (and firstCoin secondCoin))

    (given (not bothHeads) firstCoin))
"""

add_benchmark!("two_coins", "pluck_default", PluckBenchmark(two_coins_example; normalize=true))
