using StatsBase
using JSON

include("figure4_pcfg.jl")
include("figure4_sorted_fuel.jl")


using Plots

# Dict keys for sizes and times arguments are "Dice.jl", "Ours", "Enum", "Ours (SMC)"
# for each method, 'sizes[method]' is a vector of query sizes [what gets plotted on x axis]
# 'times[method]' is a vector of measured times to plot, one for each query 
#   (so sizes[method] and times[method] should have the same length, 
#    but length may vary from method to method, b/c e.g. some methods 
#    can handle bigger queries than others)


# times::Dict{String, Vector{Float64}}
function make_scaling_plot(task, sizes::Dict{String,Vector{Int}}, times; title="No title", xlabel="No label", xlims=nothing, ylims=nothing, legend=nothing)
    for key in keys(sizes)
        @assert key in ["Dice.jl", "Ours", "Enum", "Ours (SMC)"] "Invalid key: $key"
    end
    for key in keys(times)
        @assert key in ["Dice.jl", "Ours", "Enum", "Ours (SMC)"] "Invalid key: $key"
    end

    colors = Dict("Dice.jl" => :black, "Ours" => :green, "Enum" => "#0077BB", "Ours (SMC)" => :orange)

    # Find maximum size across all datasets
    max_size = maximum(maximum(sizes[k]) for k in keys(sizes))
    min_size = minimum(minimum(sizes[k]) for k in keys(sizes))

    if isnothing(xlims)
        # nearest power of 10
        xlims = (10.0^floor(log10(min_size)), 10.0^ceil(log10(max_size)))
    end
    if isnothing(ylims)
        min_time = minimum(minimum(times[k]) for k in keys(times))
        max_time = maximum(maximum(times[k]) for k in keys(times))
        ylims = (10.0^floor(log10(min_time)), 10.0^ceil(log10(max_time)))
    end

    my_plot =
        plot(
            [],
            margin=20Plots.px,
            fontsize=18,
            label=nothing,
            legendfontsize=13,
            grid=false,
            labelfontsize=18,
            linewidth=1,
            titlefontsize=18,
            tickfontsize=18,
            xlabel=xlabel,
            ylabel="Time (s)",
            legend=legend,
            title=title,
            xscale=:log10,
            yscale=:log10,
            xlims=xlims,
            ylims=ylims,
            xticks=[10.0^i for i in -10:10],
            yticks=[10.0^i for i in -10:10],
        )
    for key in ["Enum", "Dice.jl", "Ours (SMC)", "Ours"]
        if haskey(times, key) && haskey(sizes, key)
            # average times for identical sizes
            unique_sizes = unique(sizes[key])
            averaged_times = times[key]
            if length(unique_sizes) != length(sizes[key])
                averaged_times = []
                for size in unique_sizes
                    indices = findall(x -> x == size, sizes[key])
                    push!(averaged_times, StatsBase.mean(times[key][indices]))
                end
            end

            # plot
            plot!([], color=colors[key], label=key, linewidth=2)
            plot!(my_plot, unique_sizes, averaged_times, label=nothing, linewidth=6, color=colors[key])
        else
            # println("Warning: $key not found in times or sizes")
        end
    end

    # Replace spaces and special characters with underscores for safe filename
    safe_filename = replace(title, r"[^a-zA-Z0-9]" => "_")
    mkpath("out/plots")
    path = "out/plots/figure-4-$(task).pdf"
    savefig(my_plot, path)
    println("wrote ", path)
    savefig(my_plot, path[1:end-4] * ".png")
    println("wrote ", path[1:end-4] * ".png")
    return my_plot
end

strategy_of_method = Dict("Dice.jl" => "dice", "Ours" => "ours", "Enum" => "lazy_enum", "Ours (SMC)" => "smc")


function get_input_sizes(task)
    if task == "diamond"
        our_sizes = [collect(1:10)..., collect(20:10:100)..., collect(200:50:550)...]
        enum_sizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        Dict(
            "Ours" => our_sizes,
            "Dice.jl" => our_sizes,
            "Enum" => enum_sizes
        )
    elseif task == "ladder"
        our_sizes = [collect(1:10)..., collect(20:10:100)..., collect(200:50:750)...]
        enum_sizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
        Dict(
            "Ours" => our_sizes,
            "Dice.jl" => our_sizes,
            "Enum" => enum_sizes
        )
    elseif task == "hmm"
        our_sizes = [collect(5:5:100)..., collect(200:50:650)...]
        enum_sizes = [our_sizes[1:3]..., 16, 17]
        Dict(
            "Ours" => our_sizes,
            "Dice.jl" => our_sizes,
            "Ours (SMC)" => our_sizes,
            "Enum" => enum_sizes
        )
    elseif task == "sorted"
        Dict("Enum" => collect(1:5:101), "Dice.jl" => collect(1:9), "Ours" => collect(1:5:101), "Ours (SMC)" => collect(1:5:101))
    elseif task == "pcfg"
        ours_sizes = get_ours_inputs_pcfg()[:input_sizes]
        dice_sizes = get_dice_inputs_pcfg()[:input_sizes]
        Dict(
            "Ours" => ours_sizes,
            "Dice.jl" => dice_sizes,
            "Enum" => ours_sizes,
            "Ours (SMC)" => ours_sizes
        )
    else
        error("Invalid task: $task")
    end
end

function make_benchmark(task, method, size; idx=nothing)
    if task == "diamond"
        if method == "Ours" || method == "Enum"
            return PluckBenchmark("(diamond_network $size)"; pre=diamond_defs)
        elseif method == "Dice.jl"
            return DiceBenchmark(() -> pr(iterate_diamond(true, size)))
        end
    elseif task == "ladder"
        if method == "Ours" || method == "Enum"
            return PluckBenchmark("(run_ladder_network $size)"; pre=ladder_defs)
        elseif method == "Dice.jl"
            return DiceBenchmark(() -> pr(iterate_ladder(true, false, size)))
        end
    elseif task == "hmm"
        if method == "Ours" || method == "Enum"
            return PluckBenchmark("(hmm_example $size)"; pre=hmm_defs)
        elseif method == "Ours (SMC)"
            return PluckBenchmark("(hmm_example_smc $size)"; pre=hmm_defs)
        elseif method == "Dice.jl"
            return DiceBenchmark(() -> dice_hmm_example(size))
        end
    elseif task == "sorted"
        full_list = [0, 3, 7, 12, 13, 15, 16, 20, 21, 25, 29, 30, 36, 40, 44, 48, 50, 51, 55, 56, 57, 62, 64, 68, 70, 71, 75, 77, 78:150...]
        input_list = full_list[1:size]
        if method == "Ours" || method == "Enum"
            return PluckBenchmark(generate_sorted_list_test(input_list); pre=sorted_defs)
        elseif method == "Ours (SMC)"
            return PluckBenchmark(generate_sorted_list_test(input_list; equality="(suspendible-list=? nats_equal)"); pre=sorted_defs)
        elseif method == "Dice.jl"
            return DiceBenchmark(() -> pr(lists_equal(gen_sorted_list(length(input_list) + 1, Nat.Z(), 6), make_list(input_list))))
        end
    elseif task == "pcfg"
        @assert idx !== nothing "idx is required for pcfg"
        if method == "Ours" || method == "Enum"
            input = get_ours_inputs_pcfg()[:inputs][idx]
            @assert length(input) == size "input length ($size) does not match size ($size)"
            return PluckBenchmark("(list_symbols_equal (generate_pcfg_grammar (SS)) $(make_string_from_julia_list(input)))"; pre=pcfg_defs)
        elseif method == "Ours (SMC)"
            input = get_ours_inputs_pcfg()[:inputs][idx]
            @assert length(input) == size "input length ($size) does not match size ($size)"
            return PluckBenchmark("(suspendible-list=? symbol_equals (generate_pcfg_grammar (SS)) $(make_string_from_julia_list(input)))"; pre=pcfg_defs)
        elseif method == "Dice.jl"
            input = get_dice_inputs_pcfg()[:inputs][idx]
            input = replace(input, :a => :aa, :b => :bb, :c => :cc)
            fuel = get_dice_inputs_pcfg()[:fuels][idx]
            @assert length(input) == size "input length ($size) does not match size ($size)"
            return DiceBenchmark(() -> pcfg_example(input, fuel, size + 1))
        end
    else
        error("Invalid task: $task")
    end
end

function methods_of_task(task)
    if task == "diamond"
        return ["Dice.jl", "Ours", "Enum"]
    elseif task == "ladder"
        return ["Dice.jl", "Ours", "Enum"]
    elseif task == "hmm"
        return ["Dice.jl", "Ours", "Enum", "Ours (SMC)"]
    elseif task == "sorted"
        return ["Dice.jl", "Ours", "Enum", "Ours (SMC)"]
    elseif task == "pcfg"
        return ["Dice.jl", "Ours", "Enum", "Ours (SMC)"]
    else
        error("Invalid task: $task")
    end
end


function plot_settings(task)
    if task == "diamond"
        return (
            title="Network Reachability (Diamond)",
            xlabel="Network Size",
            xlims=(10^1, 10^3),
            ylims=(10^-4, 10^1)
        )
    elseif task == "ladder"
        return (
            title="Network Reachability (Ladder)",
            xlabel="Network Size",
            xlims=(10^1, 10^3),
            ylims=(10^-4, 10^2)
        )
    elseif task == "hmm"
        return (
            title="HMM",
            xlabel="Chain Length",
            xlims=(10^1, 10^3),
            ylims=(10^-3, 10^2)
        )
    elseif task == "sorted"
        return (
            title="Sorted List Generation",
            xlabel="List Length",
            xlims=(10^0, 10^2),
            ylims=(10^-4, 10^2)
        )
    elseif task == "pcfg"
        return (
            title="PCFG",
            xlabel="String Length",
            xlims=(10^1, 10^3),
            ylims=(10^-3, 10^2)
        )
    else
        error("Invalid task: $task")
    end
end

function run_scaling(task, methods=methods_of_task(task))
    all_times = Dict{String,Vector{Float64}}()
    for method in methods
        input_sizes = get_input_sizes(task)[method]
        method_times = Float64[]
        printstyled("running ", length(input_sizes), " benchmarks for $method\n", color=:yellow)
        for (i, size) in enumerate(input_sizes)
            println("size=$size ($(percent_progress(i, input_sizes))%)")
            benchmark = make_benchmark(task, method, size; idx=i)
            _, timing = run_benchmark(benchmark, strategy_of_method[method]; fast=true)
            push!(method_times, timing / 1000)
        end
        all_times[method] = method_times
        # println("Times so far for $task:")
        # println(all_times)
    end

    path = "data_to_plot/figure4/$(task).json"
    mkpath(dirname(path))
    open(path, "w") do f
        JSON.print(f, all_times, 2)
    end
    println("Wrote $path")
    nothing
end

percent_progress(i::Int, total::Int) = round(Int, 100 * i / total)
percent_progress(i::Int, total::Vector) = percent_progress(i, length(total))

function plot_scaling(task; sizes=get_input_sizes(task))
    path = "data_to_plot/figure4/$(task).json"
    times = open(path, "r") do f
        JSON.parse(f)
    end
    plot_scaling(task, times; sizes=sizes)
end

function plot_scaling(task, times; sizes=get_input_sizes(task))
    settings = plot_settings(task)
    make_scaling_plot(task, sizes, times; settings...)
end
