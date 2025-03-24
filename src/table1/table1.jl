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

function table1_sizes(; which=:original)
    printstyled("=== Evaluating Table 1 Sizes [$which] ===\n"; color=:green)
    rows = Dict(:original => original_rows, :added => added_rows)[which]
    for row in rows
        printstyled("evaluating $row\n"; color=:green)
        benchmark = get_benchmark(row, "ours")
        run_benchmark(benchmark, "ours"; show_bdd_size=true, fast=true)
    end
end

function table1(strategy; which=:original, cache=false)
    printstyled("=== Evaluating Table 1 [$which] ($strategy) ===\n"; color=:green)
    rows = Dict(:original => original_rows, :added => added_rows)[which]
    for row in rows
        if !cache || !has_cell(strategy, row)
            table1_cell(strategy, row)
        else
            printstyled("using cached result for $strategy on $row\n"; color=:blue)
        end
    end
end

function has_cell(strategy, row)
    isfile("out/table1/$strategy/$row.json")
end

function get_cell(strategy, row)
    open("out/table1/$strategy/$row.json", "r") do f
        json = JSON.parse(f)
        json["timing"]
    end
end

function show_table1(;which=:original, latex=false)
    rows = Dict(:original => original_rows, :added => added_rows)[which]
    # load all the timings
    timings = Dict()
    for strategy in ["eager_enum", "lazy_enum", "dice", "ours"]
        timings[strategy] = Dict()
        for row in rows
            if has_cell(strategy, row)
                timings[strategy][row] = get_cell(strategy, row)
            else
                timings[strategy][row] = "missing"
            end
        end
    end

    print_table(["Benchmark", "Eager Enum (ms)", "Lazy Enum (ms)", "Dice (ms)", "Ours (ms)"], timings, rows, ["eager_enum", "lazy_enum", "dice", "ours"]; latex=latex)
end

function table1_cell(strategy, benchmark_name; force=false)
    benchmark = get_benchmark(benchmark_name, strategy)
    
    res = nothing

    timing = if isnothing(benchmark)
        printstyled("missing benchmark for $strategy on $benchmark_name\n"; color=:red)
        "no_benchmark"
    elseif benchmark.skip && !force
        @assert !benchmark.timeout "can't be both skip and timeout"
        printstyled("skipping [marked to skip] $strategy on $benchmark_name\n"; color=:yellow)
        "skipped"
    elseif benchmark.timeout && !force
        printstyled("skipping [expected timeout] $strategy on $benchmark_name\n"; color=:yellow)
        "timeout"
    else
        println("evaluating: $strategy on $benchmark_name")
        res, timing = isnothing(benchmark.run_benchmark) ? run_benchmark(benchmark, strategy) : benchmark.run_benchmark(benchmark, strategy)
        timing
    end    

    json = Dict(
        "timing" => timing
    )

    path = "out/table1/$strategy/$benchmark_name.json"
    mkpath(dirname(path))
    open(path, "w") do f
        JSON.print(f, json, 2)
    end
    println("wrote $path")

    return timing
end




