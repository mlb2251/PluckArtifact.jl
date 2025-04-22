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

function diff_table1(;which=:original, threshold=.2, actual_dir="out/table1", expected_dir="out/table1_expected")
    rows = Dict(:original => original_rows, :added => added_rows)[which]
    
    # Load timings from both directories
    actual_timings = load_timings_for_dir(actual_dir, rows)
    expected_timings = load_timings_for_dir(expected_dir, rows)
    
    # Compute differences
    diff_timings = compute_diff_timings(actual_timings, expected_timings, rows, threshold)
    
    # Display the diff table
    print_diff_table(["Benchmark", "Eager Enum diff", "Lazy Enum diff", "Dice diff", "Ours diff"], 
                    diff_timings, rows, ["eager_enum", "lazy_enum", "dice", "ours"])
end

# Helper function to load timings from a directory
function load_timings_for_dir(dir_path, rows)
    timings = Dict()
    for strategy in ["eager_enum", "lazy_enum", "dice", "ours"]
        timings[strategy] = Dict()
        for row in rows
            if isfile("$dir_path/$strategy/$row.json")
                timings[strategy][row] = get_cell_from_file("$dir_path/$strategy/$row.json")
            else
                timings[strategy][row] = "missing"
            end
        end
    end
    return timings
end

function diff_results(dirs...)
    # get all unique json files in all dirs
    row_files = unique(vcat([readdir(dir) for dir in dirs if isdir(dir)]...))

    mismatch_errors = []
    for row_file in row_files
        all_dirs = []
        all_worlds = []
        for dir in dirs
            if isfile("$dir/$row_file")
                json = JSON.parse(read("$dir/$row_file", String))
                (!haskey(json, "result") || json["result"] == "missing" || isnothing(json["result"])) && continue
                push!(all_dirs, dir)
                push!(all_worlds, json["result"])
            end
        end
        if length(all_dirs) <= 1
            printstyled("not enough results to compare: $row_file only exists for $(all_dirs)\n"; color=:yellow)
            continue
        end
        mismatch = compare_results(all_dirs, all_worlds, row_file)
        mismatch && push!(mismatch_errors, row_file)
    end

    if isempty(mismatch_errors)
        printstyled("no mismatches found\n"; color=:green, bold=true)
    else
        printstyled("mismatches found on: $(join(mismatch_errors, ", "))\n"; color=:red, bold=true)
    end

    nothing
end

function compare_results(all_dirs, all_worlds, row_file)
    all_worlds = [sort(collect(worlds); by=world->world[2], rev=true) for worlds in all_worlds]

    reference_dir = first(all_dirs)
    reference_worlds = first(all_worlds)
    any_mismatch = false

    for (dir, worlds) in zip(all_dirs[2:end], all_worlds[2:end])
        mismatch = false
        mismatch |= length(worlds) != length(reference_worlds)
        mismatch |= any(zip(reference_worlds, worlds)) do (ref, other)
            ref_world, ref_prob = ref
            other_world, other_prob = other
            !isapprox(ref_prob, other_prob, atol=1e-6)
        end
        any_mismatch |= mismatch
        if mismatch
            printstyled("mismatch on $row_file between $reference_dir and $dir\n"; color=:red)
            println("$reference_dir/$row_file:")
            for (world, prob) in reference_worlds
                println("  $world: $prob")
            end
            println("$dir/$row_file:")
            for (world, prob) in worlds
                println("  $world: $prob")
            end
        else
            printstyled("no mismatch on $row_file between $reference_dir and $dir\n"; color=:green)
        end
    end
    any_mismatch
end


# Helper function to compute diff timings between actual and expected
function compute_diff_timings(actual_timings, expected_timings, rows, threshold)
    diff_timings = Dict()
    for strategy in ["eager_enum", "lazy_enum", "dice", "ours"]
        diff_timings[strategy] = Dict()
        for row in rows
            actual = actual_timings[strategy][row]
            expected = expected_timings[strategy][row]
            
            if actual isa Number && expected isa Number
                abs_diff = actual - expected
                pct_diff = 100.0 * abs_diff / expected
                
                # Format the difference with color if above threshold
                diff_str = @sprintf("%+.1f%% (%.2f)", pct_diff, actual)
                
                if abs(pct_diff) > threshold * 100
                    color = pct_diff > 0 ? :red : :green
                    diff_timings[strategy][row] = (diff_str, color)
                else
                    diff_timings[strategy][row] = diff_str
                end
            else
                diff_timings[strategy][row] = "missing"
            end
        end
    end
    return diff_timings
end

# Helper function to get cell from a specific file path
function get_cell_from_file(file_path)
    open(file_path, "r") do f
        json = JSON.parse(f)
        json["timing"]
    end
end

# Custom print function for colored diff output
function print_diff_table(headers, diff_timings, rows, colnames)
    col_widths = [length(h) for h in headers]
    
    # First pass to get maximum column widths for all cells
    for row_name in rows
        col_widths[1] = max(col_widths[1], length(string(row_name)))
        for (i, colname) in enumerate(colnames)
            cell = get(diff_timings[colname], row_name, "missing")
            cell_text = cell isa Tuple ? cell[1] : string(cell)
            col_widths[i+1] = max(col_widths[i+1], length(cell_text))
        end
    end
    
    # Add padding
    col_widths .+= 1
    
    # Process rows with now-known column widths
    processed_rows = []
    for row_name in rows
        row = Any[row_name]
        for colname in colnames
            cell = get(diff_timings[colname], row_name, "missing")
            push!(row, cell)
        end
        push!(processed_rows, row)
    end
    
    # Print headers
    for (i, (width, header)) in enumerate(zip(col_widths, headers))
        print(rpad(header, width))
    end
    println()
    println("-" ^ sum(col_widths))
    
    # Print rows with colored cells
    for row in processed_rows
        for (i, (width, cell)) in enumerate(zip(col_widths, row))
            if i == 1 || !(cell isa Tuple)
                print(rpad(string(cell), width))
            else
                cell_text, color = cell
                printstyled(rpad(cell_text, width); color=color)
            end
        end
        println()
    end
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
        "timing" => timing,
        "result" => res
    )

    path = "out/table1/$strategy/$benchmark_name.json"
    mkpath(dirname(path))
    open(path, "w") do f
        JSON.print(f, json, 2)
    end
    println("wrote $path")

    return timing
end




