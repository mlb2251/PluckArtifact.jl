module PluckArtifact

const PA = PluckArtifact

export PA, artifact, table1, figure4, figure5

using Revise
using BenchmarkTools
using Printf
using Profile
using PProf
using Pluck
using Dice # for baseline

include("figure5/figure5.jl")

function artifact()
    table1()
    figure4()
    figure5()
end

end