
function figure4()
    println("Running Experiments for Figure 4...")
end

using Plots

# Dict keys for sizes and times arguments are "Dice.jl", "Ours", "Enum", "Ours (SMC)"
# for each method, 'sizes[method]' is a vector of query sizes [what gets plotted on x axis]
# 'times[method]' is a vector of measured times to plot, one for each query 
#   (so sizes[method] and times[method] should have the same length, 
#    but length may vary from method to method, b/c e.g. some methods 
#    can handle bigger queries than others)


# times::Dict{String, Vector{Float64}}
function make_scaling_plot(sizes::Dict{String,Vector{Int}}, times; title="No title", xlabel="No label", xlims=nothing, ylims=nothing, legend=nothing)
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
            plot!([], color=colors[key], label=key, linewidth=2)
            plot!(my_plot, sizes[key], times[key], label=nothing, linewidth=6, color=colors[key])
        else
            println("Warning: $key not found in times or sizes")
        end
    end

    # Replace spaces and special characters with underscores for safe filename
    safe_filename = replace(title, r"[^a-zA-Z0-9]" => "_")
    mkpath("out/plots")
    savefig(my_plot, "out/plots/$(safe_filename)_scaling_plot.pdf")
    return my_plot

end

strategy_of_method = Dict("Dice.jl" => "dice", "Ours" => "ours", "Enum" => "lazy_enum")


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
    else
        error("Invalid task: $task")
    end
end

function expected_times(task)
    if task == "diamond"
        Dict{String,Vector{Float64}}(
            "Ours" => [0.000209209, 0.000265667, 0.000323916, 0.00038545800000000004, 0.000465291, 0.000502875, 0.0005607499999999999, 0.00061775, 0.000694375, 0.000752042, 0.001415834, 0.002115916, 0.002918791, 0.0037919589999999997, 0.0047480000000000005, 0.005945667, 0.0069786250000000005, 0.008506875, 0.010358125, 0.02920075, 0.043689167, 0.064130834, 0.083176958, 0.11983208399999999, 0.151050917, 0.19608245800000002, 0.22140979100000002],
            "Enum" => [5.4375e-5, 0.000165208, 0.000410375, 0.000948083, 0.002121833, 0.004766042, 0.010430624999999999, 0.022744958, 0.049855458, 0.106925292, 0.240661541, 0.515412208, 1.1536319590000002, 2.4502675, 5.331263042],
            "Dice.jl" => [0.000889292, 0.0005330420000000001, 0.000488, 0.000470417, 0.0005369589999999999, 0.000694458, 0.000753417, 0.000629291, 0.0006062499999999999, 0.000661833, 0.000975916, 0.001094459, 0.001408625, 0.00185, 0.002319958, 0.002590125, 0.003078125, 0.003626458, 0.003840417, 0.010261292, 0.015098083, 0.021145416, 0.032825209, 0.04010825, 0.050368541999999995, 0.06376245800000001, 0.087926333]
        )
    elseif task == "ladder"
        Dict{String,Vector{Float64}}(
            "Dice.jl" => [0.000430083, 0.000489834, 0.000579334, 0.0007152500000000001, 0.0007910829999999999, 0.000801125, 0.000900041, 0.001042291, 0.001112042, 0.0011555, 0.002012208, 0.0029373339999999998, 0.0039578750000000005, 0.005608084, 0.0067679590000000005, 0.008160875000000001, 0.00935875, 0.01135375, 0.013347666999999999, 0.047049959, 0.077344208, 0.128981584, 0.172965375, 0.257951667, 0.31432991600000004, 0.343027875, 0.437904375, 0.572281125, 0.651458, 0.777745958, 0.9256492919999999],
            "Ours" => [0.000217042, 0.000300875, 0.000387208, 0.0005026659999999999, 0.0005902500000000001, 0.0006921669999999999, 0.000807792, 0.000922167, 0.0010551669999999999, 0.001172792, 0.002674625, 0.004905417, 0.008474875000000002, 0.012690791000000002, 0.016888, 0.025458917, 0.029302708, 0.042328625, 0.050769458999999996, 0.240828166, 0.40150074999999996, 0.549183125, 0.795929917, 1.129239583, 1.396698292, 1.909677875, 2.3144765, 2.6128570829999997, 3.2066255839999998, 3.774069167, 4.407123833],
            "Enum" => [3.9625e-5, 0.00010291699999999999, 0.000226917, 0.000470334, 0.0009527919999999999, 0.00192275, 0.0038699159999999997, 0.007733958, 0.015708292, 0.031931834, 0.06438683299999999, 0.131603792, 0.277651959, 0.595705416, 1.199130292, 2.6187403330000003, 5.309653041, 11.333896875]
        )
    elseif task == "hmm"
        Dict{String,Vector{Float64}}(
            "Dice.jl" => [0.000578042, 0.000723, 0.000888458, 0.0010858749999999998, 0.0012795, 0.001448833, 0.001653292, 0.001878792, 0.002109375, 0.0023414169999999997, 0.00269525, 0.0029768750000000004, 0.003224167, 0.0034976250000000003, 0.004174125, 0.0041919589999999994, 0.00465825, 0.0053275829999999995, 0.005425083, 0.005839792, 0.021292167, 0.0415175, 0.052639125, 0.083106583, 0.121027416, 0.156760167, 0.188294792, 0.240061834, 0.298757792, 0.33134825],
            "Ours" => [0.000595041, 0.0010889580000000001, 0.001731458, 0.002469291, 0.003566417, 0.004566792, 0.006335291, 0.007614, 0.00968025, 0.011866541, 0.014243083, 0.016469459, 0.020083375, 0.025082542, 0.028004124999999998, 0.032479334, 0.035258166, 0.045686208, 0.054218458, 0.061112291, 0.28840641699999997, 0.484022958, 0.680832125, 0.952601083, 1.3734514999999998, 1.744533375, 2.203066042, 3.0153116669999998, 3.439089542, 4.013321042],
            "Enum" => [0.003298584, 0.178954417, 8.709622167, 18.786668042000002, 40.4584215] # 86.964305, 182.200289542
        )
    else
        error("Invalid task: $task")
    end
end

function make_benchmark(task, method, size)
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
        elseif method == "Dice.jl"
            return DiceBenchmark(() -> dice_hmm_example(size))
        elseif method == "Ours (SMC)"
            error("todo") # TODO add SMC
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
        return ["Dice.jl", "Ours", "Enum"] # TODO add SMC
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
            ylims=(10^-3, 10^1)
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
            benchmark = make_benchmark(task, method, size)
            _, timing = run_benchmark(benchmark, strategy_of_method[method])
            push!(method_times, timing / 1000)
        end
        all_times[method] = method_times
        println("Times so far for $task:")
        println(all_times)
    end
    return all_times
end

percent_progress(i::Int, total::Int) = round(Int, 100 * i / total)
percent_progress(i::Int, total::Vector) = percent_progress(i, length(total))

function plot_scaling(task; sizes=get_input_sizes(task), times=expected_times(task))
    settings = plot_settings(task)
    make_scaling_plot(sizes, times; settings...)
end
