module PluckArtifact

const PA = PluckArtifact

export PA, artifact, table1, figure4, figure5

using Revise
using BenchmarkTools
using Printf
using Profile
using PProf
using VTP
using Dice # for baseline

include("utils.jl")
include("figure4/figure4.jl")
include("figure5/figure5.jl")

function artifact()
    table1()
    figure4()
    figure5()
end

end