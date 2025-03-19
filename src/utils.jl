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