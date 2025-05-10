
include("dice.jl")
include("seq_grammars.jl")

using JSON: JSON
using Dates: Dates
using ProgressBars
using Random

Base.@kwdef struct GroupConfig
    config = nothing
    tasks::Vector{PTask} = []
    task_info::Vector{Dict} = []
    repetitions::Int = 1
    out::String = joinpath(timestamp_dir(), "expt")
    verbose::Bool = false
    publish::Bool = false
    warmstart::Bool = true
    warmstart_only::Bool = false
    is_warmstart::Bool = false
end
JSON.lower(x::GroupConfig) = Dict(:num_tasks => length(x.tasks), :repetitions => x.repetitions, :config => x.config)
Base.show(io::IO, x::GroupConfig) = print(io, "GroupConfig($(length(x.tasks)), $(x.repetitions), $(x.config))")

function Pluck.warmstart_config(x::GroupConfig)
    GroupConfig(
        warmstart_config(x.config),
        x.tasks[1:min(3, length(x.tasks))],
        x.task_info[1:min(3, length(x.task_info))],
        1, # repetitions
        joinpath("out/warmstart/", x.out),
        false,
        false,
        false,
        false,
        true,
    )
end

function solve_tasks(config::GroupConfig)

    if config.warmstart
        printstyled("WARMSTARTING\n", color = :yellow)
        solve_tasks(warmstart_config(config))
        printstyled("WARMSTARTING DONE\n", color = :yellow)
        config.warmstart_only && return
    end

    config.is_warmstart || printstyled("STARTING\n", color = :green)

    summary = new_summary(config)
    config.is_warmstart || printstyled("Solving $(length(config.tasks)) tasks $(config.repetitions) times each with $(Threads.nthreads()) threads\n", color = :blue)
    config.is_warmstart || printstyled(summary_address(summary); color = :yellow)
    config.is_warmstart || println("")

    # shuffle workloads for hopes of more even distribution over cpus
    num_workloads = length(config.tasks) * config.repetitions
    workloads::Vector{Tuple{Int, Int}} = collect(enumerate(1:num_workloads))
    progress = ProgressBar(workloads)

    tstart = time()


    tdds = [TimeDataDict() for _ in 1:length(workloads)]
    function process(idx, i_j)
        task_idx = (i_j - 1) ÷ config.repetitions + 1
        rep_idx = (i_j - 1) % config.repetitions + 1
        task = config.tasks[task_idx]
        try
            stub = copy(summary[:init_stubs_of_task][task_idx][rep_idx])
            config.verbose && println("[$(task.name) $rep_idx] Starting")
            res = solve_task(config.config, task)
            config.verbose && println("[$(task.name) $rep_idx] Done")
            tdd = tdds[idx]
            for r in res
                add_timing_data!(tdd, r.tdd)
            end
            config.verbose && is_solved(res) && printstyled("[$(task.name) $rep_idx] solved\n", color = :green)
            write_out(res, joinpath(stub[:out], stub[:path]); browser_path = html_path(config.config), verbose = config.verbose)
            write_stub(finish_stub!(res, stub); publish = config.publish, verbose = config.verbose)
            config.verbose && println(summary_address(summary))
            config.verbose && println("") # necessary bc the next printed line will get eaten by the progress bar
        catch e
            print("[$(task.name) $rep_idx] ERROR: ")
            showerror(stdout, e)
            println()
            println()
            Pluck.SINGLE_THREAD && rethrow()
            e isa InterruptException && rethrow()
        end
    end

    if !Pluck.SINGLE_THREAD && config.config isa MCMCConfig
        Threads.@threads :greedy for idx__i_j in progress
            process(idx__i_j[1], idx__i_j[2])
        end
    else
        for (idx, i_j) in progress
            process(idx, i_j)
        end
    end

    tdd = TimeDataDict()
    for tdd_inner in tdds
        add_timing_data!(tdd, tdd_inner)
    end

    dt = time() - tstart
    println("dt: ", round(Int, dt), "s")
    println(tdd)
    summary[:tdd] = string(tdd)
    summary[:dt] = dt
    write_out(summary, joinpath(config.out, summary[:summary_path]); browser_path = "html/summary.html", publish = config.publish, verbose = config.verbose)
    config.is_warmstart || !config.publish || println("View results at ", summary_address(summary))

    return summary
end

struct TaskDist
    grammar::Grammar
    input_type::String
    output_type::String
    input_dist::String
    valid_expr::Function
    valid_io::Function
end

JSON.lower(task_dist::TaskDist) = Dict(
    :grammar => string(task_dist.grammar),
    :input_type => task_dist.input_type,
    :output_type => task_dist.output_type,
    :input_dist => task_dist.input_dist,
)

function default_equality_fn(type::String)
    Dict(
        "list" => "old_list_eq",
        "unit" => "constructors_equal",
        "bool" => "constructors_equal",
        "int" => "nat_eq",
    )[type]
end

struct Dataset
    task_dist::TaskDist
    tasks::Vector{PTask}
    task_info::Vector{Dict}
    path::String
end

Dataset(task_dist) = Dataset(task_dist, [], [], joinpath(timestamp_dir(; base="out/fuzz-datasets/"), "dataset.json"))

function make_fuzzing_dataset(; N=100, M=4, E=4, task_dist=map_unit_grammar())

    input_types = PType[parse_type(task_dist.input_type)]
    output_type = parse_type(task_dist.output_type)
    # @show task_dist.grammar
    # @show task_dist.grammar.start_expr_of_type[output_type]
    start = parsed_expr(task_dist.grammar, task_dist.grammar.start_expr_of_type[output_type], output_type, input_types)

    dataset = Dataset(task_dist)

    seen = Set{String}()

    progress = ProgressBar(; total=N)
    set_description(progress, "Generating dataset")

    while length(dataset.tasks) < N
        # expr = Pluck.random(pcfg_dist, pcfg, Pluck.from_lhs_detached(start))

        # Sample expr
        size_dist = Pluck.Uniform(0, 10)
        size = Pluck.random(size_dist)
        expr = Pluck.random(Pluck.fixed_size_dist, task_dist.grammar, size, Pluck.from_lhs_detached(start))

        q_expr = Pluck.logprob(Pluck.fixed_size_dist, task_dist.grammar, size, expr) + Pluck.logprob(size_dist, size)

        # reject invalid exprs and duplicates
        !task_dist.valid_expr(string(expr)) && continue
        string(expr) in seen && continue
        push!(seen, string(expr))

        # sample input output examples
        ios = IOExample[]
        p_inputs = []
        for i in 1:M+E
            input = sample_output(task_dist.input_dist)
            # @show input
            p_input, stats = bdd_constrain(task_dist.input_dist, [to_value(nothing)], input; root_equality_fn=default_equality_fn(task_dist.input_type))
            @assert p_input > -Inf
            output = nothing
            for j in 1:20
                output = sample_output(string(expr); env=Any[input])
                !isnothing(output) && break
            end
            isnothing(output) && break
            !task_dist.valid_io(from_value(input), from_value(output)) && break
            push!(ios, IOExample(Value[input], output))
            push!(p_inputs, p_input)
        end

        length(ios) < M + E && continue # means we hit one of the break statements

        name = lpad(length(dataset.tasks), 3, '0')

        push!(dataset.tasks, PTask(Symbol(name), parse_type("$(task_dist.input_type) -> $(task_dist.output_type)"), ios; solution=expr.expr.child, num_train=M))
        push!(dataset.task_info, Dict(:size => size, :q_expr => q_expr, :p_inputs => p_inputs))
        update(progress)
    end

    # write to file
    write_out(dataset, dataset.path)
    return dataset.path
end

function make_tc(mode::Symbol; temperature=1.0, train_only=false, kwargs_of_task)

    if mode == :bdd
        return task -> TaskConstrain(task, BDDEvalStateConfig(; kwargs_of_task(task)...); temperature, train_only)
    elseif mode == :lazy
        return task -> TaskConstrain(task, LazyEnumeratorConfig(; kwargs_of_task(task)...); temperature, train_only)
    elseif mode == :strict
        return task -> TaskConstrain(task, LazyEnumeratorConfig(; strict=true, disable_traces=true, disable_cache=true, kwargs_of_task(task)...); temperature, train_only)
    elseif mode == :smc
        return task -> TaskConstrain(task, BDDEvalStateConfig(; bdd_forward_fn=bdd_forward_with_suspension, root_equality_fn="suspended_list_eq ==", kwargs_of_task(task)...); temperature, train_only)
    elseif mode == :dice
        return task -> TaskConstrain(task, DiceConfig(; kwargs_of_task(task)...); temperature, train_only)
    else
        error("Unknown mode $mode")
    end
end


function get_historical_data()
    res = Vector{Dict}()
    target_dir = "data/figure5"
    open(joinpath(target_dir, "historical_nov14.json")) do f
        data = JSON.parse(f)
        for group in data["groups"]
            if haskey(group, "gen_file") && haskey(group, "eval_file")
                task = group["config"]["task"]
                gen_file = joinpath(target_dir, group["gen_file"])
                eval_file = joinpath(target_dir, group["eval_file"])
                push!(res, Dict(:task => task, :gen_file => gen_file, :eval_file => eval_file))
            end
        end
    end
    return res
end


function figure5_left_single(mode; truncate=10, time_limit=1.0, max_depth=1000)
    more_defs()
    historical_data = get_historical_data()
    for data in historical_data
        println("Fuzzing task: ", data[:task])
        eval_file = fuzz(data[:gen_file], mode; truncate, time_limit, max_depth)
        write_figure5_left_single(mode, data[:task], eval_file)
    end
end

function write_figure5_left_single(mode, task, eval_file)
    file = "data_to_plot/figure5-left/$(mode)/$(task).json"
    mkpath(dirname(file))
    open(file, "w") do f
        JSON.print(f, Dict(:eval_file => eval_file), 2)
    end
    println("Wrote $file")
end

function figure5_right_single(mode; truncate=8, time_limit=0.05, max_depth=1000, mcmc_steps=500, repetitions=1)
    more_defs()
    historical_data = get_historical_data()
    for data in historical_data
        println("Synthesizing task: ", data[:task])
        out_dir = synth(data[:eval_file], mode, data[:task]; truncate, time_limit, max_depth, mcmc_steps, repetitions)
        write_figure5_right_single(mode, data[:task], out_dir)
    end
end

function write_figure5_right_single(mode, task, out_dir)
    file = "data_to_plot/figure5-right/$(mode)/$(task).json"
    mkpath(dirname(file))
    open(file, "w") do f
        JSON.print(f, Dict(:synth_file => out_dir), 2)
    end
    println("Wrote $file")
end

all_tasks = [
    "cIID-Gen",
    "cIID-IO",
    "Markov-Gen",
    "Markov-IO",
    "HMM-Gen",
    "HMM-Gen-IO"
]
all_modes = [:bdd, :dice, :lazy, :smc]

function build_figure5_right()
    data = open("data/figure5/synthesis_result_template.json") do f
        JSON.parse(f)
    end
    for task in all_tasks
        group = findfirst(g -> g["config"]["task"] == task, data["groups"])
        @assert !isnothing(group)
        group = data["groups"][group]
        @assert isempty(group["runs"])
        for mode in all_modes
            path = "data_to_plot/figure5-right/$(mode)/$(task).json"
            if !isfile(path)
                continue
            end
            res = open(path) do f
                JSON.parse(f)
            end
            path = res["synth_file"]
            push!(group["runs"], Dict(:mode => mode, :path => path * "/summary.json"))
        end
    end
    open("data_to_plot/figure5-right/synthesis_result.json", "w") do f
        JSON.print(f, data, 2)
    end
    println("Wrote data_to_plot/figure5-right/synthesis_result.json")
end

function build_figure5_left()
    data = open("data/figure5/fuzzing_result_template.json") do f
        JSON.parse(f)
    end
    for task in all_tasks
        group = findfirst(g -> g["config"]["task"] == task, data["groups"])
        @assert !isnothing(group)
        group = data["groups"][group]
        @assert !haskey(group, "eval_file")

        # initialize with first mode
        first_mode = all_modes[1]
        path = "data_to_plot/figure5-left/$(first_mode)/$(task).json"
        eval_file = open(path) do f
            JSON.parse(f)["eval_file"]
        end
        merged = open(eval_file) do f
            JSON.parse(f)
        end

        group["eval_file"] = merged
        for mode in all_modes[2:end]
            path = "data_to_plot/figure5-left/$(mode)/$(task).json"
            if !isfile(path)
                continue
            end
            eval_file = open(path) do f
                JSON.parse(f)["eval_file"]
            end
            to_add = open(eval_file) do f
                JSON.parse(f)
            end
            mode_str = String(mode)
            for i in 1:length(merged["task_info"])
                merged["task_info"][i]["res"][mode_str] = to_add["task_info"][i]["res"][mode_str]
            end
        end
        # write out the combined eval_file
        dir = "data_to_plot/figure5-left/combined"
        mkpath(dir)
        open(joinpath(dir, "$(task).json"), "w") do f
            JSON.print(f, merged, 2)
        end
        println("Wrote $dir/$(task).json")
        group["eval_file"] = joinpath(dir, "$(task).json")
    end
    open("data_to_plot/figure5-left/fuzzing_result.json", "w") do f
        JSON.print(f, data, 2)
    end
    println("Wrote data_to_plot/figure5-left/fuzzing_result.json")
end


function fuzz(gen_file, mode; truncate=10, time_limit=1.0, max_depth=1000)
    dataset_json = open(gen_file) do f
        JSON.parse(f)
    end

    # TEMPORARY
    if !isnothing(truncate)
        dataset_json["tasks"] = dataset_json["tasks"][1:truncate]
        dataset_json["task_info"] = dataset_json["task_info"][1:truncate]
    end

    tasks = [from_json(PTask, task) for task in dataset_json["tasks"]]
    task_info = dataset_json["task_info"]

    dataset_json["time_limit"] = time_limit

    progress = collect(1:length(tasks))
    progress = ProgressBar(progress)
    set_description(progress, "Evaluating")
    GC.gc()
    Threads.@threads :greedy for i in progress
        task = tasks[i]
        task_info[i]["res"] = Dict()

        kwargs_of_task = task -> (; time_limit, max_depth, state_vars=StateVars(; fuel=autofuel(task)))
        eval_builder = make_tc(mode; kwargs_of_task)
        task_constrain_fn = eval_builder(task)
        train_res = task_constrain_fn(task.solution; cache=false, test=false)
        test_res = task_constrain_fn(task.solution; cache=false, test=true)
        task_info[i]["res"][mode] = Dict("train_res" => train_res, "test_res" => test_res)

    end

    dir = timestamp_dir(; base="out/fuzzing-evaluation/")
    file = joinpath(dir, "results.json")
    write_out(dataset_json, file)
    return file
end

function synth(eval_file, mode, task; max_depth=1000, temperature=1.0, mcmc_steps=1000, repetitions=1, time_limit=0.05, truncate=8)
    task_dist = grammar_of_task(task)
    evaluate_solution = full_evaluate_solution
    results = Dict()

    kwargs_of_task = task -> (; time_limit, max_depth, state_vars=StateVars(; fuel=autofuel(task)))
    eval_builder = make_tc(mode; kwargs_of_task, temperature, )
    cfg = MCMCConfig(; steps=mcmc_steps, pcfg=task_dist.grammar, eval_builder, evaluate_solution)
    println("Running MCMC with $mode")
    GC.gc()
    # println("Memory usage before MCMC: $(mem_usage_mb()) MB")
    summary = mcmc_eval(cfg, eval_file; repetitions, truncate)
    addr = summary_address(summary)
    printstyled("  $mode: $addr\n", color=:green)
    results[mode] = addr

    return summary[:out]
end

function fuzzing_evaluation(dataset_path; time_limit=3.0, truncate=nothing, max_depth=1000, modes=[:bdd, :dice, :lazy, :smc])
    dataset_json = open(dataset_path) do f
        JSON.parse(f)
    end

    if !isnothing(truncate)
        dataset_json["tasks"] = dataset_json["tasks"][1:truncate]
        dataset_json["task_info"] = dataset_json["task_info"][1:truncate]
    end

    tasks = [from_json(PTask, task) for task in dataset_json["tasks"]]
    task_info = dataset_json["task_info"]

    dataset_json["time_limit"] = time_limit

    progress = collect(1:length(tasks))
    progress = ProgressBar(progress)
    set_description(progress, "Evaluating")
    GC.gc()
    Threads.@threads :greedy for i in progress
        task = tasks[i]
        # res = Dict()
        # raw_expr = string(task.solution)
        task_info[i]["res"] = Dict()
        # @show i
        # @show task.solution
        # @show task.ios
        for mode in modes
            # @show mode
            kwargs_of_task = task -> (; time_limit, max_depth, state_vars=StateVars(; fuel=autofuel(task)))
            eval_builder = make_tc(mode; kwargs_of_task)
            task_constrain_fn = eval_builder(task)
            train_res = task_constrain_fn(task.solution; cache=false, test=false)
            test_res = task_constrain_fn(task.solution; cache=false, test=true)
            task_info[i]["res"][mode] = Dict("train_res" => train_res, "test_res" => test_res)
        end

    end

    dir = timestamp_dir(; base="out/fuzzing-evaluation/")
    file = joinpath(dir, "results.json")
    write_out(dataset_json, file)
    addr = webaddress("html/fuzzing.html", file, false)
    println(addr)
    return file
end

function mcmc_eval(cfg, dataset_path; repetitions=3, warmstart=true, truncate=nothing)
    dataset_json = open(dataset_path) do f
        JSON.parse(f)
    end
    tasks = [from_json(PTask, task) for task in dataset_json["tasks"]]
    task_info = dataset_json["task_info"]

    if !isnothing(truncate)
        tasks = tasks[1:truncate]
        task_info = task_info[1:truncate]
    end

    gcfg = GroupConfig(; tasks, task_info, config=cfg, repetitions, warmstart)
    GC.gc()
    solve_tasks(gcfg)
end

function full_evaluate_solution(expr, task)
    time_limit = 3.0
    max_depth = 1000
    state_vars = StateVars(; fuel=autofuel(task))
    configs = [
        BDDEvalStateConfig(; time_limit, max_depth, state_vars),
        DiceConfig(; time_limit, max_depth, state_vars),
        LazyEnumeratorConfig(; time_limit, max_depth, state_vars),
    ]
    train_res = test_res = nothing
    for config in configs
        tc = TaskConstrain(task, config; temperature=1.0)
        if isnothing(train_res)
            try_train_res = tc(expr; cache=false, test=false)
            if !try_train_res.stats.hit_limit
                train_res = try_train_res
            end
        end
        if isnothing(test_res)
            try_test_res = tc(expr; cache=false, test=true)
            if !try_test_res.stats.hit_limit
                test_res = try_test_res
            end
        end
    end
    return train_res, test_res
end
