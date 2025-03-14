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

murder_mystery_example = """
(let (aliceDunnit (flip 0.3)
      withGun (if aliceDunnit (flip 0.03) (flip 0.8))
      gunFound (flip 0.5)
      obs (if withGun gunFound (not gunFound)))
      (given obs aliceDunnit))
"""

add_benchmark!("murder_mystery", "pluck_default", PluckBenchmark(murder_mystery_example; kwargs=Dict(:normalize => true)))
