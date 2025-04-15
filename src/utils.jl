"""
Adaptation of btime from BenchmarkTools.jl
"""
macro bbtime(args...)
    _, params = BenchmarkTools.prunekwargs(args...)
    bench, trial, result = gensym(), gensym(), gensym()
    trialmin, trialmean, trialallocs = gensym(), gensym(), gensym()
    tune_phase = BenchmarkTools.hasevals(params) ? :() : :($BenchmarkTools.tune!($bench))
    return esc(
        quote
            local $bench = $BenchmarkTools.@benchmarkable $(args...)
            $tune_phase
            local $trial, $result = $BenchmarkTools.run_result(
                $bench; warmup=$(BenchmarkTools.hasevals(params))
            )
            local $trialmin = $BenchmarkTools.minimum($trial)
            local $trialmean = $BenchmarkTools.mean($trial)
            local $trialallocs = $BenchmarkTools.allocs($trialmin)
            println(
                "  time=",
                $BenchmarkTools.time($trialmin)/1e6, " ms",
                " mean=",
                $BenchmarkTools.time($trialmean)/1e6, " ms",
                " (",
                $trialallocs,
                " allocation",
                $trialallocs == 1 ? "" : "s",
                ": ",
                $BenchmarkTools.prettymemory($BenchmarkTools.memory($trialmin)),
                ")",
            )
            ($result, $BenchmarkTools.time($trialmin)/1e6)
        end,
    )
end


function print_table(headers, timings, rownames, colnames; latex=false)
    @assert length(colnames) == length(headers) - 1
    dicts = [get(timings, colname, Dict()) for colname in colnames]
    rows = rows_from_dicts(dicts, headers, rownames)
    if latex
        latex_table(rows, headers)
    else
        print_table_from_rows(rows, headers)
    end
end

"""
Convert a list of dictionaries into a list of rows, where each dict is a column,
and the rows are the union of the keys of the dicts, and the headers are the column headers
(so there's one more header than there are dicts because there's the column for keys).
The rownames parameter specifies the order of rows to include.
"""
function rows_from_dicts(dicts, headers::Vector{String}, rownames::Vector{String})
    rows = []
    for key in rownames
        row = Any[key]
        for dict in dicts
            push!(row, get(dict, key, "missing"))
        end
        push!(rows, row)
    end
    return rows
end

function print_table_from_rows(rows, headers)
    col_widths = [length(h) for h in headers]

    # Convert numeric cells to formatted strings
    rows = map(rows) do row
        map(enumerate(row)) do (i, cell)
            cell = cell isa Number ? @sprintf("%.2f", cell) : cell
            col_widths[i] = max(col_widths[i], length(cell))
            cell
        end
    end

    col_widths .+= 2
    col_widths[end] -= 2

    for (padding, header) in zip(col_widths, headers)
        print(rpad(header, padding))
    end
    println()
    println("-" ^ sum(col_widths))

    for row in rows
        for (padding, cell) in zip(col_widths, row)
            print(rpad(cell, padding))
        end
        println()
    end
end



# 
# \quad Alarm (37 nodes) &  \textcolor{red}{timeout} & \textcolor{red}{timeout} & \underline{130.82~ms} & \textbf{78.75~ms} & 296 & 94,947 \\

function latex_table(rows, headers)

    # Convert numeric cells to formatted strings
    rows = map(rows) do row
        # sort the cells that are numbers
        sorted_order = map((i_cell) -> i_cell[1], sort(filter(i_cell -> i_cell[2] isa Number, collect(enumerate(row))), by = x -> x[2]))
        # @show sorted_order
        # @show [row[i] for i in sorted_order]
        map(enumerate(row)) do (i, cell)
            if i == 1
                title = Dict(
                    "noisy_or" => "Noisy Or (8 nodes)",
                    "burglary" => "Burglary (6 nodes)",
                    "evidence1" => "Evidence 1",
                    "evidence2" => "Evidence 2",
                    "grass" => "Grass",
                    "murder_mystery" => "Murder Mystery",
                    "two_coins" => "Two Coins",
                    "cancer" => "Cancer (5 nodes)",
                    "survey" => "Survey (6 nodes) ",
                    "alarm" => "Alarm (37 nodes) ",
                    "insurance" => "Insurance (27 nodes)",
                    "hepar2" => "Hepar2 (70 nodes)",
                    "hailfinder" => "Hailfinder (56 nodes)",
                    "pigs" => "Pigs (441 nodes)",
                    "water" => "Water (32 nodes)",
                    "munin" => "Munin (1041 nodes)",
                    "diamond" => "Diamond Network",
                    "ladder" => "Ladder Network",
                    "hmm" => "HMM (50 steps)",
                    "pcfg" => "PCFG (23 terminals)",
                    "string_editing" => "String Editing (4\$\\to\$5 chars)",
                    "sorted_list" => "Sorted List Gen. (8 elements)",
                    "dice_figure_1" => "Figure 1 from \\citet{holtzen2020scaling}",
                    "caesar" => "Caesar Cipher (100 chars)",
                )[cell]
                cell = "\\quad $title"
                return cell
            end

            cell = cell isa Number ? @sprintf("%.2f~ms", cell) : "\\textcolor{red}{$cell}"
            if length(sorted_order) > 0 && i == sorted_order[1]
                cell = "\\textbf{$cell}"
            elseif length(sorted_order) > 1 && i == sorted_order[2]
                cell = "\\underline{$cell}"
            end
            cell
        end
    end

    for (i, row) in enumerate(rows)
        for (j, cell) in enumerate(row)
            if j == 1
                printstyled(cell, " & "; color=:green)
            else
                print(cell, " & ")
            end
        end
        println("\\\\")
    end
end

function mem_usage_mb()
    pid = getpid()
    if Sys.isunix()
        # Get RSS and VSZ for the current process
        cmd = `ps -o rss=,vsz= -p $pid`
        output = read(cmd, String)
        rss, vsz = parse.(Int, split(strip(output)))
        return rss ÷ 1024
    else
        # Fallback for non-Unix systems
        # return Base.gc_num()
        # @warn "Memory usage not supported on non-Unix systems"
        return 0
    end
end