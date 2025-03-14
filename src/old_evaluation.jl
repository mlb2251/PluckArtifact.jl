

include("from_dice/noisy_or.jl")
include("from_dice/cancer_bayes_net.jl")
include("from_dice/network_verification.jl")
include("from_dice/burglary.jl")
include("hmm.jl")
include("from_dice/pcfg.jl")
include("spelling_correction.jl")
include("sorted_list_generation.jl")

function run_all_bdd(; kwargs...)
    println("Running noisy or bdd")
    run_noisy_or_bdd(; kwargs...)
    println("Running cancer bdd")
    run_cancer_bdd(; kwargs...)
    println("Running network bdd")
    run_network_bdd(; kwargs...)
    println("Running burglary bdd")
    run_burglary_bdd(; kwargs...)
    println("Running hmm bdd")
    run_hmm_bdd(; kwargs...)
    println("Running pcfg bdd")
    run_pcfg_bdd(; kwargs...)
    println("Running spell test bdd")
    run_spell_test_bdd(; kwargs...)
    println("Running sorted list bdd")
    run_sorted_list_bdd(; kwargs...)
end

function run_all_lazy_kwargs(; skip_hmm=false, skip_spelling=false, skip_sorted=false, pcfg_fuel=nothing, spelling_fuel=nothing, sorted_fuel=nothing, kwargs...)
    println("Running noisy or")
    run_noisy_or_lazy(; kwargs...)
    println("Running cancer")
    run_cancer_lazy(; kwargs...)
    println("Running network")
    run_network_lazy(; kwargs...)
    println("Running burglary")
    run_burglary_lazy(; kwargs...)
    println("Running hmm")
    skip_hmm ? println("skipping hmm lazy because we expect a timeout") : run_hmm_lazy(; kwargs...)
    println("Running pcfg fuel=$pcfg_fuel")
    run_pcfg_lazy(; fuel=pcfg_fuel, kwargs...)
    println("Running spell test fuel=$spelling_fuel")
    skip_spelling ? println("skipping spell test lazy because we expect a timeout") : run_spell_test_lazy(; fuel=spelling_fuel, kwargs...)
    println("Running sorted list fuel=$sorted_fuel")
    skip_sorted ? println("skipping sorted list lazy because we expect a timeout") : run_sorted_list_lazy(; fuel=sorted_fuel, kwargs...)
end

function run_all_lazy_yescache()
    run_all_lazy_kwargs(; skip_hmm=true, disable_traces=true)
    println("======= sanity check about the timeout: expect ~7s or more =====")
    hmm_defs()
    @bbtime lazy_enumerate("(hmm_example 13)")
end

function run_all_lazy_nocache()
    run_all_lazy_kwargs(; skip_hmm=true, disable_cache=true)
    println("======= sanity check about the timeout: expect ~2s or more =====")
    hmm_defs()
    @bbtime lazy_enumerate("(hmm_example 13)"; disable_cache=true)
end

function run_all_strict()
    pcfg_fuel = 82
    spelling_fuel = 10
    sorted_fuel = (11, 5)
    kwargs = (strict=true, disable_cache=true, disable_traces=true)
    run_all_lazy_kwargs(; skip_hmm=true, skip_spelling=true, skip_sorted=true, pcfg_fuel=pcfg_fuel, spelling_fuel=spelling_fuel, sorted_fuel=sorted_fuel, kwargs...)
    println("======= sanity check about the stackoverflow for HMM =====")
    hmm_defs()
    try 
        lazy_enumerate("(hmm_example 13)"; kwargs...)
    catch e
        println("caught an error: $e")
    end
    println("======= sanity check about the timeout: expect ~54s or more =====")
    perturb_defs()
    lazy_enumerate(spell_test_fuel(1); kwargs...) # warmstart
    @time lazy_enumerate(spell_test_fuel(2); kwargs...)
    println("======= sanity check about the timeout: expect ~57s or more =====")
    sorted_defs()
    lazy_enumerate(test_to_perform_fuel(11, 1); kwargs...) # warmstart
    @time lazy_enumerate(test_to_perform_fuel(11, 2); kwargs...)
end

