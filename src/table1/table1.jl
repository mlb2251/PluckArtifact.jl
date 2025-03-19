include("bayesian_networks/large_networks/large_networks.jl")

for name in small_bayes_nets
    include("bayesian_networks/small_networks/pluck/$name.jl")
    include("bayesian_networks/small_networks/dice/$name.jl")
end

for name in network_models
    include("network_verification/pluck/$name.jl")
    include("network_verification/dice/$name.jl")
end

for name in sequence_models
    include("sequence_models/pluck/$name.jl")
    include("sequence_models/dice/$name.jl")
end


function table1()
    printstyled("=== Evaluating Table 1 ===\n"; color=:green)

    table1_timings = Dict()

    for strategy in ["ours", "dice", "lazy_enum", "eager_enum"]
        printstyled("=== Evaluating $strategy ===\n"; color=:blue)
        for row in original_rows
            evaluate_cell!(table1_timings, strategy, row)
        end
        for row in added_rows
            evaluate_cell!(table1_timings, strategy, row)
        end
    end
    println(table1_timings)

    println("Original submission benchmarks:")
    print_table(["Benchmark", "Eager Enum (ms)", "Lazy Enum (ms)", "Dice (ms)", "Ours (ms)"], table1_timings, original_rows, ["eager_enum", "lazy_enum", "dice", "ours"])
    println()
    println("Added benchmarks:")
    print_table(["Benchmark", "Eager Enum (ms)", "Lazy Enum (ms)", "Dice (ms)", "Ours (ms)"], table1_timings, added_rows, ["eager_enum", "lazy_enum", "dice", "ours"])

    table1_timings
end

function evaluate_cell!(timings, strategy, baseline)
    benchmark = get_benchmark(baseline, strategy)
    subtimings = get!(Dict, timings, strategy)
    
    if isnothing(benchmark)
        printstyled("missing benchmark for $strategy on $baseline\n"; color=:red)
        subtimings[baseline] = "missing"
        return nothing
    end

    if benchmark.skip
        @assert !benchmark.timeout "can't be both skip and timeout"
        printstyled("skipping $strategy on $baseline\n"; color=:yellow)
        subtimings[baseline] = "skipped"
        return nothing
    end

    if benchmark.timeout
        printstyled("skipping $strategy on $baseline\n"; color=:yellow)
        subtimings[baseline] = "timeout"
        return nothing
    end

    # @assert !haskey(subtimings, baseline) "timing for $baseline already exists"
    println("evaluating: $strategy on $baseline")
    println("MEM: $(mem_usage_mb()) MB")
    res, timing = isnothing(benchmark.run_benchmark) ? run_benchmark(benchmark, strategy) : benchmark.run_benchmark(benchmark, strategy)
    subtimings[baseline] = timing
    return res
end




