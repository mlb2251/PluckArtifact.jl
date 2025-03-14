# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/evidence2.dice
# let evidence = flip 0.5 in
#     if evidence then
#         let coin1  = flip 0.5 in
#         let tmp = observe coin1 in
#         coin1
#     else
#         flip 0.5

function evidence2_dice()
    code = @dice begin
        evidence = flip(0.5)
        @dice_ite if evidence
            coin1 = flip(0.5)
            observe(coin1)
            coin1
        else
            flip(0.5)
        end
    end
    return pr(code)
end

add_benchmark!("evidence2", "dice_default", DiceBenchmark(evidence2_dice))