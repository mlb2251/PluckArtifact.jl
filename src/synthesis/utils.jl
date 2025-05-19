mutable struct TimeData
    time::Float64
    bytes::Int64
    gctime::Float64
    gcstats::Base.GC_Diff
    compile_time::Float64
    recompile_time::Float64
end

function Base.show(io::IO, td::TimeData)
    print(io, "(time=", td.time, ", bytes=", td.bytes, ", gctime=", td.gctime, ", gcstats=", td.gcstats, ")")
end

mutable struct TimeDataDict
    dict::Dict{Symbol, TimeData}
    order::Vector{Symbol}
end
function Base.show(io::IO, tdd::TimeDataDict)
    isempty(tdd.dict) && return print(io, "TimeDataDict()")
    print(io, "TimeDataDict(")

    rpad_sym = maximum(length.(string.(tdd.order)))

    # Time
    times = [tdd.dict[sym].time for sym in tdd.order]
    total_time = sum(times)
    relative_times = times ./ total_time
    print(io, "\n  Time: ", round2(total_time), "s")
    for (sym, time, relative_time) in zip(tdd.order, times, relative_times)
        print(io, "\n    ", rpad(sym, rpad_sym), " => ", rpad(string(round2(relative_time * 100), "%"), 5), " (", round2(time), "s)")
    end

    # GCTime 
    gctimes = [tdd.dict[sym].gctime for sym in tdd.order]
    total_gctime = sum(gctimes)
    if total_gctime > 0
        frac_gc = total_gctime / total_time
        relative_gctimes = gctimes ./ total_gctime
        print(io, "\n  GC Time: ", round2(total_gctime), "s (", round2(frac_gc * 100), "%)")
        for (sym, gctime, relative_gctime) in zip(tdd.order, gctimes, relative_gctimes)
            print(io, "\n    ", rpad(sym, rpad_sym), " => ", rpad(string(round2(relative_gctime * 100), "%"), 5), " (", round2(gctime), "s)")
        end
    end

    # Compile Time
    compile_times = [tdd.dict[sym].compile_time for sym in tdd.order]
    total_compile_time = sum(compile_times)
    if total_compile_time > 0
        frac_compile = total_compile_time / total_time
        relative_compile_times = compile_times ./ total_compile_time
        print(io, "\n  Compile Time: ", round2(total_compile_time), "s (", round2(frac_compile * 100), "%)")
        for (sym, compile_time, relative_compile_time) in zip(tdd.order, compile_times, relative_compile_times)
            print(io, "\n    ", rpad(sym, rpad_sym), " => ", rpad(string(round2(relative_compile_time * 100), "%"), 5), " (", round2(compile_time), "s)")
        end
    end

    # Recompile Time
    recompile_times = [tdd.dict[sym].recompile_time for sym in tdd.order]
    total_recompile_time = sum(recompile_times)
    if total_recompile_time > 0
        frac_recompile = total_recompile_time / total_time
        relative_recompile_times = recompile_times ./ total_recompile_time
        print(io, "\n  Recompile Time: ", round2(total_recompile_time), "s (", round2(frac_recompile * 100), "%)")
        for (sym, recompile_time, relative_recompile_time) in zip(tdd.order, recompile_times, relative_recompile_times)
            print(io, "\n    ", rpad(sym, rpad_sym), " => ", rpad(string(round2(relative_recompile_time * 100), "%"), 5), " (", round2(recompile_time), "s)")
        end
    end

    # Bytes
    bytes = [tdd.dict[sym].bytes for sym in tdd.order]
    total_bytes = sum(bytes)
    relative_bytes = bytes ./ total_bytes
    print(io, "\n  Bytes: ", round2(total_bytes), " bytes")
    for (sym, bytes, relative_byte) in zip(tdd.order, bytes, relative_bytes)
        print(io, "\n    ", rpad(sym, rpad_sym), " => ", rpad(string(round2(relative_byte * 100), "%"), 5), " (", round2(bytes), " bytes)")
    end


    print(io, "\n)")
end



TimeDataDict() = TimeDataDict(Dict{Symbol, TimeData}(), Symbol[])

function add_timing_data!(tdd::TimeDataDict, sym, timed_result)
    td = get!(tdd.dict, sym) do
        push!(tdd.order, sym)
        TimeData()
    end
    add_timing_data!(td, timed_result)
end

function add_timing_data!(tdd::TimeDataDict, tdd2::TimeDataDict)
    for sym in tdd2.order
        if haskey(tdd.dict, sym)
            add_timing_data!(tdd.dict[sym], tdd2.dict[sym])
        else
            tdd.dict[sym] = tdd2.dict[sym]
            push!(tdd.order, sym)
        end
    end
end


TimeData() = TimeData(0.0, 0, 0.0, Base.GC_Diff(0, 0, 0, 0, 0, 0, 0, 0, 0), 0.0, 0.0)

function add_timing_data!(td::TimeData, timed_result)
    td.time += timed_result.time
    td.bytes += timed_result.bytes
    td.gctime += timed_result.gctime

    old = td.gcstats
    new = timed_result.gcstats
    td.gcstats = Base.GC_Diff(
        old.allocd + new.allocd, # Bytes allocated
        old.malloc + new.malloc,          # Number of GC aware malloc()
        old.realloc + new.realloc,        # Number of GC aware realloc()
        old.poolalloc + new.poolalloc,    # Number of pool allocations
        old.bigalloc + new.bigalloc,      # Number of big (non-pool) allocations
        old.freecall + new.freecall,      # Number of GC aware free()
        old.total_time + new.total_time,  # Time spent in garbage collection
        old.pause + new.pause,            # Number of GC pauses
        old.full_sweep + new.full_sweep,  # Number of GC full collections
    )
    td.compile_time += timed_result.compile_time
    td.recompile_time += timed_result.recompile_time
    nothing
end

round3(x) = round(x; sigdigits = 3)
round2(x) = round(x; sigdigits = 2)
round1(x) = round(x; sigdigits = 1)
round0(x) = round(x; sigdigits = 0)