include("translation.jl")
include("codegen.jl")

data_dir = "data/large_bayes_nets"

names = ["cancer", "survey", "water", "alarm", "insurance", "hepar2", "pigs", "hailfinder", "munin"]

# which variable to get the single marginal of
target_vars::Dict{String, Symbol} = Dict(
    "alarm" => :BP,
    "cancer" => :Dyspnoea,
    "hailfinder" => :R5Fcst,
    "hepar2" => :jaundice,
    "insurance" => :PropCost,
    "pigs" => :p48084991,
    "survey" => :T,
    "water" => :CNON_12_45,
    "munin" => :L_SUR_CV_CA
)

expected_outputs = Dict(
    "alarm" => [(0, 0.38999308773414654), (1, 0.20470776251260087), (2, 0.4052991497532523), (3, 0.0)],
    "cancer" => [(0, 0.3040705), (1, 0.6959294999999999)],
    "hailfinder" => [(0, 0.25206480542413834), (1, 0.44059947932150173), (2, 0.3073357152543599), (3, 0.0)],
    "hepar2" => [(0, 0.2719147607671873), (1, 0.7280852392328125)],
    "insurance" => [(0, 0.5629455909005231), (1, 0.3151875947814524), (2, 0.10507029426792233), (3, 0.01679652005010235)],
    "pigs" => [(0, 0.2656249999748047), (1, 0.4687500000078124), (2, 0.2656250000173828), (3, 0.0)],
    "survey" => [(0, 0.5618339760097999), (1, 0.28085725199020023), (2, 0.15730877199999996), (3, 0.0)],
    "water" => [(0, 0.004161748754297062), (1, 0.9047758779258376), (2, 0.09106235327587024), (3, 2.0043995018129032e-8)],
    "munin" => [(0, 0.008716364148532453), (1, 0.0001237557537930512), (2, 0.0008255742377163428), (3, 0.0015344946621133775), (4, 0.0015667764969255586), (5, 0.0013746809661952988), (6, 0.0018831614905352439), (7, 0.0020968149527313216), (8, 0.004044895489278196), (9, 0.009388818407956679), (10, 0.034088231795036374), (11, 0.09472751695144571), (12, 0.29201934141813285), (13, 0.3541139707266835), (14, 0.15438224661460737), (15, 0.03637682276538774), (16, 0.0027365331229289008), (17, 0.0), (18, 0.0), (19, 0.0), (20, 0.0), (21, 0.0), (22, 0.0), (23, 0.0), (24, 0.0), (25, 0.0), (26, 0.0), (27, 0.0), (28, 0.0), (29, 0.0), (30, 0.0), (31, 0.0)]
)


"""
Get the variable order from the .bif.dice file. so that we can use the same variable
order as dice
"""
function get_var_order(name)
    file = "$data_dir/$name.bif.dice"
    vars = Symbol[]
    open(file) do f
        for line in eachline(f)
            if startswith(line, "let ")
                # "parse let C_NI_12_00 = " into C_NI_12_00
                var = split(line, " = ")[1]
                var = split(var, "let ")[2]
                push!(vars, Symbol(var))
            end
        end
    end
    return vars
end

function setup_large_net_pluck(name; use_int_dist=false, remove_unused=false, dice_ordering=true)
    # print("parsing...")
    vars, probs = parse_bif("$data_dir/$name.bif")

    # either match ordering to dice's ordering, or do a topological_sort
    if dice_ordering
        var_order = get_var_order(name)
        @assert length(var_order) == length(probs)
        probs = sort(probs, by = p -> findfirst(==(p.target), var_order))
    else
        probs = topological_sort(probs)
    end

    # decide on the target var
    target_var =target_vars[String(name)]
    # print("(target var=$target_var)...")

    if remove_unused
        probs = remove_unused_vars(probs, target_var)
    end

    # print("codegen...")
    outfile = "$data_dir/$name.lisp"
    code = generate_bayes_net_code(vars, probs, target_var; outfile, use_int_dist=use_int_dist)
    
    return code
end

function run_net(name; mode=:time, eager=false, kwargs...)
    bn = setup_large_net_pluck(name; use_int_dist=false, remove_unused=false, dice_ordering=true)
    bn = parse_expr(bn)

    if eager
        f = () -> bdd_forward_strict(bn; state=BDDStrictEvalState(;kwargs...), kwargs...)
    else
        f = () -> bdd_forward(bn; state=LazyKCState(;kwargs...))
    end

    println("running...")

    benchtime = nothing

    GC.gc()
    res = if mode == :time
        @time f()
    elseif mode == :btime
        @btime f()
    elseif mode == :bbtime
        res, benchtime = @bbtime $f()
        res
    elseif mode == :profile
        Profile.clear()
        @time Profile.@profile f()
        pprof()
    elseif mode == :none
        # nothing
    else
        error("Invalid mode: $mode")
    end

    if !isnothing(res) && !isnothing(expected_outputs[name])

        if res isa Vector{Tuple{Value, Float64}}
            # map symbols to their index
            tmp = map(res) do (val, prob)
                (findfirst(==(val.constructor), vars[target_var].domain)-1, prob)
            end
            sort!(tmp, by = t -> t[1])

            for i in eachindex(expected_outputs[name])
                if length(tmp) < i || tmp[i][1] != i-1
                    insert!(tmp, i, (i-1, 0.0))
                end
            end

            res = tmp
            
        end
        for i in eachindex(expected_outputs[name])
            expected_val, expected_prob = expected_outputs[name][i]
            actual_val, actual_prob = res[i] # should both just be in increasing order 0 1 2 ...
            @assert isapprox(expected_prob, actual_prob, atol=1e-6) "expected $expected_prob, got $actual_prob"
        end
    else
        printstyled("did not check outputs for $name\n", color=:red)
    end

    return res, benchtime
end

"""
Convert a .bif.dice file to a .jl file that Dice.jl can ingest
"""
function setup_large_net_dice(name)
    infile = "$data_dir/$name.bif.dice"
    outfile = "$data_dir/$name.jl.ignore" # .ignore because otherwise the files are so big they crash vscode
    target_var = target_vars[name]
    convert_dice_code(name, infile, outfile, target_var);
    return `julia --project $outfile`
end

function run_large_net_dice(name)
    cmd = setup_large_net_dice(name)
    # Run the Julia command and capture both stdout and stderr in the output variable
    println("Executing $cmd")
    # stderr_to = devnull
    @time "full command took" output = read(pipeline(cmd, stderr=stderr), String)
    
    # Extract timing from output
    m = match(r"Time: ([0-9.]+)", output)
    if m === nothing
        error("Could not find timing in output: $output") 
    end
    benchtime = parse(Float64, m[1])
    
    # Extract result from output
    m = match(r"Result: (Dict\(.*?\))"s, output, 1)
    if m === nothing
        error("Could not find result in output: $output") 
    end

    result = eval(Meta.parse(m[1]))

    println("Time: $benchtime ms")
    
    return result, benchtime
end

function dice_large_bayes_nets()
    res = Dict()
    for name in names
        if name == "munin"
            println("Skipping $name because it takes ~17 minutes to compile. Run manually with PA.run_large_net_dice(\"$name\")")
            res[name] = "missing"
            continue
        end

        println("Running $name")
        _, benchtime = run_large_net_dice(name)
        res[name] = benchtime
    end
    return res
end

function ours_large_bayes_nets(;kwargs...)
    res = Dict()
    for name in names
        println("Running $name")
        _, benchtime = run_net(name; kwargs...)
        res[name] = benchtime
    end
    return res
end

for name in names
    make_query = () -> setup_large_net_pluck(name)
    add_benchmark!(name, "pluck_default", PluckBenchmark(""; make_query = make_query))
    timeout_strict_enum = !(name in ["cancer", "survey"])
    add_benchmark!(name, "pluck_strict_enum", PluckBenchmark(""; make_query = make_query, timeout=timeout_strict_enum))
    timeout_lazy_enum = !(name in ["cancer", "survey", "water"])
    add_benchmark!(name, "pluck_lazy_enum", PluckBenchmark(""; make_query = make_query, timeout=timeout_lazy_enum))
end

for name in names
    skip = name == "munin"
    add_benchmark!(name, "dice_default", DiceBenchmark(() -> (); skip=skip, run_benchmark = (benchmark, strategy) -> run_large_net_dice(name)))
end
