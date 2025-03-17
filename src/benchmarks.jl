

mutable struct PluckBenchmark
    query::String
    normalize::Bool
    pre::Union{Function, Nothing}
    run_benchmark::Union{Function, Nothing}
    make_query::Union{Function, Nothing}
    skip::Bool
    kwargs::Dict{Symbol, Any}
    PluckBenchmark(query; normalize=false, pre=nothing, run_benchmark=nothing, make_query=nothing, skip=false, kwargs=Dict()) = new(query, normalize, pre, run_benchmark, make_query, skip, kwargs)
end

mutable struct DiceBenchmark
    fn_to_time::Function
    run_benchmark::Union{Function, Nothing}
    kwargs::Dict{Symbol, Any}
    skip::Bool
    DiceBenchmark(fn_to_time; run_benchmark=nothing, kwargs=Dict(), skip=false) = new(fn_to_time, run_benchmark, kwargs, skip)
end

const all_groups = ["pluck_default", "dice_default", "pluck_lazy_enum", "pluck_strict_enum"]
const groups_of_strategy = Dict(
    "ours" => ["pluck_default"],
    "dice" => ["dice_default"],
    "lazy_enum" => ["pluck_lazy_enum", "pluck_default"],
    "eager_enum" => ["pluck_strict_enum", "pluck_default"],
)

small_bayes_nets = ["burglary", "evidence1", "evidence2", "grass", "murder_mystery", "noisy_or", "two_coins"]
network_models = ["diamond", "ladder"]
sequence_models = ["pcfg", "hmm", "sorted_list", "string_editing"]
original_rows = ["noisy_or", "burglary", "cancer", "survey", "water", "alarm", "insurance", "hepar2", "pigs", "diamond", "ladder", "hmm", "pcfg", "string_editing", "sorted_list"]
added_rows = ["hailfinder", "munin", "evidence1", "evidence2", "grass", "murder_mystery", "two_coins"]
all_benchmarks = ["noisy_or", "burglary", "cancer", "survey", "water", "alarm", "insurance", "hepar2", "pigs", "diamond", "ladder", "hmm", "pcfg", "string_editing", "sorted_list", "hailfinder", "munin", "evidence1", "evidence2", "grass", "murder_mystery", "two_coins"]


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


function run_benchmark(benchmark::PluckBenchmark, strategy)
    benchmark.pre !== nothing && benchmark.pre()
    benchmark.query = isnothing(benchmark.make_query) ? benchmark.query : benchmark.make_query()
    expr = parse_expr(benchmark.query)

    fn_to_time = if strategy == "ours"
        benchmark.normalize ? () -> bdd_normalize(bdd_forward(expr)) : () -> bdd_forward(expr)
    elseif strategy == "smc"
        benchmark.normalize ? () -> bdd_normalize(bdd_forward_with_suspension(expr)) : () -> bdd_forward_with_suspension(expr)
    elseif strategy == "lazy_enum"
        benchmark.normalize ? () -> bdd_normalize(lazy_enumerate(expr)) : () -> lazy_enumerate(expr)
    elseif strategy == "eager_enum"
        strict_kwargs = Dict(:strict => true, :disable_cache => true, :disable_traces => true)
        benchmark.normalize ? () -> bdd_normalize(lazy_enumerate(expr; strict_kwargs...)) : () -> lazy_enumerate(expr; strict_kwargs...)
    else
        error("Unknown strategy: $strategy")
    end

    res, timing = @bbtime $fn_to_time()
    return res, timing
end

function run_benchmark(benchmark::DiceBenchmark, strategy)
    @assert strategy == "dice"
    res, timing = @bbtime $benchmark.fn_to_time()
    return res, timing
end