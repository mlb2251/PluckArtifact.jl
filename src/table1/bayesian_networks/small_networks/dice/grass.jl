
# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/grass.dice
# let cloudy  = flip 0.5 in
# let rain  = if cloudy then flip 0.8 else flip 0.2 in
# let sprinkler  = if cloudy then flip 0.1 else flip 0.5 in
# let temp1  = flip 0.7 in
# let wetRoof  = (temp1 && rain) in
# let temp2  = flip 0.9 in
# let temp3  = flip 0.9 in
# let wetGrass  = ((temp2 && rain) || ( temp3 && sprinkler)) in
# let tmp = observe wetGrass in
# rain

function grass_dice()
    code = @dice begin
        cloudy = flip(0.5)
        rain = ifelse(cloudy, flip(0.8), flip(0.2))
        sprinkler = ifelse(cloudy, flip(0.1), flip(0.5))
        temp1 = flip(0.7)
        wetRoof = temp1 & rain
        temp2 = flip(0.9)
        temp3 = flip(0.9)
        wetGrass = (temp2 & rain) | (temp3 & sprinkler)
        observe(wetGrass)
        rain
    end
    return pr(code)
end

add_benchmark!("grass", "dice_default", DiceBenchmark(grass_dice))