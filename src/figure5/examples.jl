using Pluck
using JSON: JSON
using Dates: Dates
using BenchmarkTools
using ProgressBars
using Random

include("example_grammars.jl")

mcmc_alex_list_ppcfg(; kwargs...) = MCMCConfig(
    cfg = alex_list_ppcfg(),
    kwargs...,
)


Base.@kwdef struct GroupConfig
    config = nothing
    tasks::Vector{PTask} = load_joshrule()[1:80]
    task_info::Vector{Dict} = []
    repetitions::Int = 1
    # temperatures::Vector{Float64} = [1.0]
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
    # workloads::Vector{Int} = Random.shuffle!(collect(1:num_workloads))
    workloads::Vector{Tuple{Int, Int}} = collect(enumerate(1:num_workloads))
    progress = ProgressBar(workloads)
    # progress = workloads

    tstart = time()

    # task_constrains = TaskConstrain[]

    tdds = [TimeDataDict() for _ in 1:length(workloads)]
    # @maybethreads for i_j in progress
    function process(idx, i_j)
        task_idx = (i_j - 1) ÷ config.repetitions + 1
        rep_idx = (i_j - 1) % config.repetitions + 1
        task = config.tasks[task_idx]
        # task_info = config.task_info[task_idx]
        # println("Start $(Threads.threadid()) $(task.name) $rep_idx")
        try
            stub = copy(summary[:init_stubs_of_task][task_idx][rep_idx])
            config.verbose && println("[$(task.name) $rep_idx] Starting")
            res = solve_task(config.config, task)
            config.verbose && println("[$(task.name) $rep_idx] Done")
            tdd = tdds[idx]
            for r in res
                add_timing_data!(tdd, r.tdd)
            end
            # config.verbose && println(config.out)
            config.verbose && is_solved(res) && printstyled("[$(task.name) $rep_idx] solved\n", color = :green)
            write_out(res, joinpath(stub[:out], stub[:path]); browser_path = html_path(config.config), verbose = config.verbose)
            # write_out(get_task_constrain_fn(res), stub[:evaltime_path]; browser_path="html/evaltime.html", verbose=config.verbose)
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

