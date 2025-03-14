# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/twocoins.dice
# let firstCoin  = flip 0.5 in 
#     let secondCoin  = flip 0.5 in
#     let bothHeads  = (firstCoin && secondCoin) in
#     let tmp = observe !bothHeads in
#     firstCoin

function two_coins_dice()
    code = @dice begin
        firstCoin = flip(0.5)
        secondCoin = flip(0.5)
        bothHeads = firstCoin & secondCoin
        observe(!bothHeads)
        return firstCoin
    end
    return pr(code)
end

add_benchmark!("two_coins", "dice_default", DiceBenchmark(two_coins_dice))