
function ladder_defs()
    @define "ladder_network" """

    (lambda i1 i2 -> 
    (let (output (flip 0.5)
            result (Cons output (not output))
            fail_result (Cons false false))
        (if i1 (if (flip 0.001) fail_result result)
        (if i2 result fail_result))))

    """

    @define "run_ladder_network" """
    (lambda m -> (case ((Y (lambda run_ladder_network n -> (case n of O => (Cons true false) | S m => (case (run_ladder_network m) of Cons i1 i2 => (ladder_network i1 i2))))) m) of Cons i1 i2 => i1))
    """
end

add_benchmark!("ladder", "pluck_default", PluckBenchmark("(run_ladder_network 100)"; pre=ladder_defs))
add_benchmark!("ladder", "pluck_strict_enum", PluckBenchmark("(run_ladder_network 100)"; pre=ladder_defs, timeout=true))
add_benchmark!("ladder", "pluck_lazy_enum", PluckBenchmark("(run_ladder_network 100)"; pre=ladder_defs, timeout=true))
