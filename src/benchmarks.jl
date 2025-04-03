

mutable struct PluckBenchmark
    query::String
    normalize::Bool
    pre::Union{Function, Nothing}
    run_benchmark::Union{Function, Nothing}
    make_query::Union{Function, Nothing}
    skip::Bool
    timeout::Bool
    kwargs::Dict{Symbol, Any}
    PluckBenchmark(query; normalize=false, pre=nothing, run_benchmark=nothing, make_query=nothing, skip=false, timeout=false, kwargs=Dict()) = new(query, normalize, pre, run_benchmark, make_query, skip, timeout, kwargs)
end

mutable struct DiceBenchmark
    fn_to_time::Function
    run_benchmark::Union{Function, Nothing}
    kwargs::Dict{Symbol, Any}
    skip::Bool
    timeout::Bool
    DiceBenchmark(fn_to_time; run_benchmark=nothing, kwargs=Dict(), skip=false, timeout=false) = new(fn_to_time, run_benchmark, kwargs, skip, timeout)
end

const all_groups = ["pluck_default", "dice_default", "pluck_lazy_enum", "pluck_strict_enum"]
const groups_of_strategy = Dict(
    "ours" => ["pluck_default"],
    "dice" => ["dice_default"],
    "lazy_enum" => ["pluck_lazy_enum", "pluck_default"],
    "eager_enum" => ["pluck_strict_enum", "pluck_default"],
)

small_bayes_nets = ["dice_figure_1", "caesar", "burglary", "evidence1", "evidence2", "grass", "murder_mystery", "noisy_or", "two_coins"]
network_models = ["diamond", "ladder"]
sequence_models = ["pcfg", "hmm", "sorted_list", "string_editing"]
original_rows = ["cancer", "survey", "alarm", "insurance", "hepar2", "hailfinder", "pigs", "water", "munin", "diamond", "ladder", "hmm", "pcfg", "string_editing", "sorted_list"]
added_rows = ["noisy_or", "burglary",  "evidence1", "evidence2", "grass", "murder_mystery", "two_coins", "caesar", "dice_figure_1"]
all_benchmarks = ["dice_figure_1", "caesar", "noisy_or", "burglary", "cancer", "survey", "water", "alarm", "insurance", "hepar2", "pigs", "diamond", "ladder", "hmm", "pcfg", "string_editing", "sorted_list", "hailfinder", "munin", "evidence1", "evidence2", "grass", "murder_mystery", "two_coins"]

const groups_of_baseline = Dict()

function add_benchmark!(baseline::String, group::String, benchmark::Union{PluckBenchmark, DiceBenchmark})
    @assert group ∈ all_groups "group $group not in all_groups"
    @assert baseline ∈ all_benchmarks "baseline $baseline not in all_benchmarks"
    groups = get!(groups_of_baseline, baseline, Dict())
    # @assert group ∉ keys(groups)
    groups[group] = benchmark
end

"""
Return the first (leftmost in groups_of_strategy list) benchmark that is defined for the baseline
"""
function get_benchmark(baseline::String, strategy::String)
    strategy_groups = groups_of_strategy[strategy]
    !haskey(groups_of_baseline, baseline) && return nothing
    baseline_groups = groups_of_baseline[baseline]
    for strategy_group in strategy_groups
        if strategy_group ∈ keys(baseline_groups)
            return baseline_groups[strategy_group]
        end
    end
    nothing
end


function run_benchmark(benchmark::PluckBenchmark, strategy::String; fast=false, kwargs...)
    benchmark.pre !== nothing && benchmark.pre()
    benchmark.query = isnothing(benchmark.make_query) ? benchmark.query : benchmark.make_query()
    expr = parse_expr(benchmark.query)
    time_limit = benchmark.timeout ? 60.0 : nothing # only for lazy and eager enumeration
    fast |= !isnothing(time_limit) # if we have a time limit, we want normal timing not bbtime

    if !isnothing(time_limit)
        println("using time limit $time_limit seconds")
    end

    fn_to_time = if strategy == "ours"
        benchmark.normalize ? () -> bdd_normalize(bdd_forward(expr; kwargs...)) : () -> bdd_forward(expr; kwargs...)
    elseif strategy == "smc"
        benchmark.normalize ? () -> bdd_normalize(bdd_forward_with_suspension(expr; kwargs...)) : () -> bdd_forward_with_suspension(expr; kwargs...)
    elseif strategy == "lazy_enum"
        benchmark.normalize ? () -> bdd_normalize(lazy_enumerate(expr; time_limit, kwargs...)) : () -> lazy_enumerate(expr; time_limit, kwargs...)
    elseif strategy == "eager_enum"
        strict_kwargs = Dict(:strict => true, :disable_cache => true, :disable_traces => true)
        benchmark.normalize ? () -> bdd_normalize(lazy_enumerate(expr; time_limit, strict_kwargs..., kwargs...)) : () -> lazy_enumerate(expr; strict_kwargs..., time_limit, kwargs...)
    else
        error("Unknown strategy: $strategy")
    end

    res, timing = do_timing(fn_to_time; fast=fast)

    hit_limit = res == []
    if !isnothing(time_limit)
        if timing > 1000 * time_limit
            # time limit
            printstyled("[expected] hit limit for $strategy\n"; color=:green)
            timing = "*timeout*"
        elseif hit_limit
            # depth or stackoverflow limit
            printstyled("[unexpected] hit non-timeout limit for $strategy in $(timing) ms\n"; color=:yellow)
        else
            printstyled("[unexpected] didn't hit time limit for $strategy instead just took $(timing) ms\n"; color=:red)
        end
    end

    return res, timing
end

function run_benchmark(benchmark::DiceBenchmark, strategy; fast=false)
    @assert strategy == "dice"
    return do_timing(benchmark.fn_to_time; fast=fast)
end

function do_timing(fn_to_time; fast=false)
    if fast
        timing1 = (@elapsed (res = fn_to_time())) * 1000;
        if timing1 > 20000
            println("Time: $(timing1/1000) s")
            return res, timing1 # don't run the second time if it's already > 20s
        end
        GC.gc();
        timing = (@elapsed fn_to_time()) * 1000
        println("Time: $(timing/1000) s")
    else
        res, timing = @bbtime $fn_to_time()
    end
    return res, timing
end
