

function run_fuel_plot()
    l = [0, 3, 7, 12, 13, 15, 16, 20]
    fuel_vals = 1:9
    min_correct_fuel = 6

    println("Running Ours")
    res, ours_query_time = run_benchmark(PluckBenchmark(generate_sorted_list_test(l); pre=sorted_defs), "ours")
    ours_query_time /= 1000
    println("Res: $res")
    
    println("Running Dice.jl with increasing fuel")
    timings = []
    for (i, fuel) in enumerate(fuel_vals)
        println("Fuel: $fuel ($(percent_progress(i, length(fuel_vals)))%)")
        benchmark = DiceBenchmark(() -> pr(lists_equal(gen_sorted_list(length(l)+1, Nat.Z(), fuel), make_list(l))))
        res, timing = run_benchmark(benchmark, "dice")
        println("Res: $res")
        push!(timings, timing/1000)
    end

    result = Dict(
        :fuel_vals => fuel_vals,
        :ours_query_time => ours_query_time,
        :timings => timings,
        :min_correct_fuel => min_correct_fuel
    )
    println("$result")
    return result
end

function expected_fuel_result()

end

function make_fuel_plot(results)
    fuel_vals = results[:fuel_vals]
    ours_query_time = results[:ours_query_time]
    timings = results[:timings]
    min_correct_fuel = results[:min_correct_fuel]

    sorted_list_plot = plot([], margin=20Plots.px, fontsize=18, label=nothing,legendfontsize=18, labelfontsize=18, linewidth=1, titlefontsize=18, tickfontsize=18, xlabel="Fuel", ylabel="Time (s)", legend=:topleft, title="Sorted List Generation")
    plot!(sorted_list_plot, [], color=:green, label="Ours", linewidth=2)
    plot!(sorted_list_plot, [], color=:red, label="Dice.jl (wrong)", linewidth=3, line=:dot)
    plot!(sorted_list_plot, [], color=:black, label="Dice.jl (correct)", linewidth=2, line=:solid)
    hline!(sorted_list_plot, [ours_query_time], color=:green, linewidth=4, label=nothing, thickness_scaling=1)
    min_correct_fuel_idx = findfirst(fuel_vals .>= min_correct_fuel)

    plot!(sorted_list_plot, fuel_vals[1:min_correct_fuel_idx], 1 .* timings[1:min_correct_fuel_idx], label=nothing, line=:dot, color=:red, linewidth=6)
    plot!(sorted_list_plot, fuel_vals[min_correct_fuel_idx:end], 1 .* timings[min_correct_fuel_idx:end], label=nothing, line=:solid, linewidth=6,color=:black)
    plot!(sorted_list_plot, grid=false)

    savefig(sorted_list_plot, "sorted_list_fuel_plot.pdf")
    return sorted_list_plot
end

