# https://github.com/SHoltzen/dice/blob/ed8671689a2a6466c8aaaee57dbc3e3b71150825/benchmarks/baselines/murderMystery.dice
# fun mystery() {
#     let aliceDunnit  = flip 0.3 in
#     let withGun = if aliceDunnit then flip 0.03 else flip 0.8 in
#     (aliceDunnit, withGun)
# }

# fun gunFoundAtScene(gunFound: bool) {
#     let res = mystery() in
#     let aliceDunnit = fst res in
#     let withGun = snd res in
#     let obs = if withGun then gunFound else !gunFound in
#     let tmp = observe obs in
#     aliceDunnit
# }

# gunFoundAtScene(true)

function murder_mystery_dice()
    code = @dice begin
        aliceDunnit = flip(0.3)
        withGun = ifelse(aliceDunnit, flip(0.03), flip(0.8))
        gunFound = flip(0.5)
        obs = ifelse(withGun, gunFound, !gunFound)
        observe(obs)
        return aliceDunnit
    end
    return pr(code)
end

add_benchmark!("murder_mystery", "dice_default", DiceBenchmark(murder_mystery_dice))