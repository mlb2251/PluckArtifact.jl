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
                "  min=",
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


function print_table(headers, timings, rownames, colnames)
    @assert length(colnames) == length(headers) - 1
    dicts = [get(timings, colname, Dict()) for colname in colnames]
    rows = rows_from_dicts(dicts, headers, rownames)
    print_table_from_rows(rows, headers)
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

