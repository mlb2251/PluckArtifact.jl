using StatsBase

include("figure4_pcfg.jl")
include("figure4_sorted_fuel.jl")

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
            println("Warning: $key not found in times or sizes")
        end
    end

    # Replace spaces and special characters with underscores for safe filename
    safe_filename = replace(title, r"[^a-zA-Z0-9]" => "_")
    mkpath("out/plots")
    savefig(my_plot, "out/plots/$(safe_filename)_scaling_plot.pdf")
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
        Dict("Enum" => collect(1:101), "Dice.jl" => collect(1:9), "Ours" => collect(1:101), "Ours (SMC)" => collect(1:101))
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
    elseif task == "sorted"
        Dict{String,Vector{Float64}}(
            "Dice.jl" => [0.000728666, 0.001576625, 0.004104958, 0.021186875, 0.07110291599999999, 0.39724120900000004, 1.428208042, 17.490467958, 38.873473624999995],
            "Ours" => [0.0003545, 0.0005425, 0.0008628329999999999, 0.00133325, 0.0018077920000000001, 0.002361875, 0.002939416, 0.003650042, 0.0043885420000000005, 0.005332917, 0.006362708, 0.00744775, 0.009133833, 0.010525375, 0.012150583, 0.014712125, 0.01622475, 0.017897375, 0.020032875000000002, 0.023228834, 0.025441833, 0.028051708, 0.030293, 0.032877083, 0.036564166999999995, 0.041479458999999996, 0.044776333, 0.047536042, 0.050870042, 0.053753833, 0.057194499999999995, 0.060650417, 0.0641825, 0.068792666, 0.076552709, 0.08074683299999999, 0.0840915, 0.088124166, 0.091429125, 0.09563933299999999, 0.100676875, 0.10425975, 0.108787833, 0.113083792, 0.118171875, 0.123193792, 0.13601216700000002, 0.1417465, 0.145067417, 0.14961966699999998, 0.15629474999999998, 0.160792375, 0.165422584, 0.171719833, 0.175028084, 0.182975625, 0.187251583, 0.190597709, 0.19927562499999998, 0.203750083, 0.20917362499999997, 0.217112458, 0.22413387499999998, 0.2298105, 0.23761633299999999, 0.25926854200000005, 0.264315792, 0.27519908299999996, 0.2791225, 0.28787570799999995, 0.29591904199999997, 0.300505709, 0.307501375, 0.315579791, 0.319467333, 0.328009, 0.3366965, 0.343291917, 0.35266037499999997, 0.358777917, 0.36892475, 0.387030958, 0.391436958, 0.39919904100000003, 0.408321333, 0.41187404099999997, 0.423422166, 0.43338245799999997, 0.445336083, 0.45714283299999997, 0.493122542, 0.5102141250000001, 0.512181458, 0.52457875, 0.531196458, 0.5433641669999999, 0.547107958, 0.562222791, 0.572576417, 0.575869625, 0.590620583],
            "Enum" => [8.6917e-5, 0.000249875, 0.000551917, 0.001060292, 0.00161, 0.00235075, 0.003216958, 0.004449916, 0.005705958, 0.0074113749999999996, 0.009428375000000001, 0.011527292, 0.014519167, 0.017502959000000002, 0.021128291, 0.025835333, 0.030638334, 0.034881541, 0.040118499999999994, 0.046573791999999996, 0.052708875, 0.060301291, 0.070947916, 0.077039791, 0.0855035, 0.0958945, 0.10667725, 0.118379333, 0.13033850000000002, 0.14367850000000001, 0.156105167, 0.172267042, 0.18730850000000002, 0.20309379100000002, 0.223127208, 0.239841, 0.256593458, 0.274178209, 0.293110333, 0.317369917, 0.337314791, 0.360478083, 0.384946625, 0.411799083, 0.465316125, 0.465859208, 0.5334293330000001, 0.534089291, 0.5529248750000001, 0.613817583, 0.632707667, 0.7087519590000001, 0.7455852089999999, 0.764291667, 0.783189041, 0.825911458, 0.885139833, 0.950430625, 0.973104042, 0.9695695, 0.99220375, 1.10221775, 1.1058655409999998, 1.2026681670000001, 1.197612708, 1.275374958, 1.3479036249999998, 1.360534292, 1.40502275, 1.510421916, 1.55811575, 1.655939292, 1.699188042, 1.791028208, 1.874316125, 1.8832987909999999, 1.966215375, 2.032048541, 2.077473334, 2.187448292, 2.278758292, 2.345979292, 2.424076917, 2.509791792, 2.654721125, 2.638361875, 2.745213625, 2.94127725, 2.971113167, 2.966521459, 3.0483376250000003, 3.130571375, 3.210146875, 3.420325875, 3.534494208, 3.537566292, 3.6180685830000003, 3.850685125, 4.289039916, 4.09357625, 4.1269402920000005]
        )
    elseif task == "pcfg"
        Dict{String,Vector{Float64}}(
            "Dice.jl" => [0.000418666, 0.00038733299999999996, 0.000538625, 0.00054725, 0.00091025, 0.000909709, 0.004948708, 0.01241025, 0.013393625, 0.03382075, 3.307854, 8.794447708, 15.189399709, 36.444958625, 36.844978583, 84.148723291],
            "Ours" => [0.0015934159999999998, 0.003292542, 0.005490917, 0.00584, 0.008906750000000001, 0.011212833, 0.016706375000000002, 0.019702165999999997, 0.020600916, 0.021367333, 0.055981292, 0.125570291, 0.15626325, 0.224890959, 0.276792125, 0.297152625, 0.449084333, 0.543065083, 0.32479874999999997, 0.5989294589999999],
            "Enum" => [0.001234292, 0.003345459, 0.005707792000000001, 0.00665725, 0.010292958000000001, 0.013910458, 0.019574583, 0.024315874999999997, 0.027816542, 0.030437417, 0.08973025, 0.159174792, 0.231440291, 0.29252691700000005, 0.418486959, 0.48418483300000004, 0.67984175, 0.742398292, 0.6898698329999999, 1.001836416]
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
            return PluckBenchmark(generate_sorted_list_test(input_list; equality="(suspended_list_eq nats_equal)"); pre=sorted_defs)
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
            return PluckBenchmark("(suspended_list_eq symbol_equals (generate_pcfg_grammar (SS)) $(make_string_from_julia_list(input)))"; pre=pcfg_defs)
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
