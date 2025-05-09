module PluckArtifact

const PA = PluckArtifact

export PA, artifact, table1, figure4, figure5, get_rsdd_time, clear_rsdd_time!, @rsdd_time

using Revise
using BenchmarkTools
using Printf
using Profile
using PProf
using Pluck
using Dice # for baseline

include("utils.jl")
include("benchmarks.jl")
include("table1/table1.jl")
include("figure4/figure4.jl")


end