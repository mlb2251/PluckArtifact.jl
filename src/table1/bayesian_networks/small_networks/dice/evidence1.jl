# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/evidence1.dice
# let evidence = flip 0.5 in
#     let coin  = flip 0.5 in
#     if evidence then
#         let tmp = observe coin in evidence
#         else evidence

function evidence1_dice()
    code = @dice begin
        evidence = flip(0.5)
        coin = flip(0.5)
        @dice_ite if evidence
            observe(coin)
            evidence
        else
            evidence
        end
    end
    return pr(code)
end

add_benchmark!("evidence1", "dice_default", DiceBenchmark(evidence1_dice))