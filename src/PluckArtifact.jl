module PluckArtifact

const PA = PluckArtifact

export PA, artifact, table1, figure4, figure5, get_rsdd_time, clear_rsdd_time!, @rsdd_time

using Revise
using BenchmarkTools
using Printf
using PProf
using Pluck
using Dice # for baseline
import Profile

include("utils.jl")
include("benchmarks.jl")
include("table1/table1.jl")
include("figure4/figure4.jl")

include("synthesis/utils.jl")
include("synthesis/types.jl")
include("synthesis/tasks.jl")
include("synthesis/subexprs.jl")
include("synthesis/grammar.jl")
include("synthesis/dists.jl")
include("synthesis/solutions.jl")
include("synthesis/mcmc.jl")
include("synthesis/bench.jl")

include("figure5/figure5.jl")

end