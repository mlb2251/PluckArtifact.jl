
"""
A builder for constructing grammars incrementally. Supports adding rules with weights
and building up complex grammars piece by piece.
"""
struct GrammarBuilder
    rules::Dict{String, Vector{Pair{String, Int}}}
    GrammarBuilder() = new(Dict{String, Vector{Pair{String, Int}}}())
    GrammarBuilder(rule::String) = add_rule!(GrammarBuilder(), rule)
end

Base.getindex(g::GrammarBuilder, lhs::String) = g.rules[lhs]

"""
Add one or more rules to the grammar builder. Rules can be specified in several formats:
1. Single rule: "?foo => ?bar" adds ?bar as a RHS for ?foo with weight 1
2. Multiple rules: "?foo => ?bar 2 | ?baz 3" adds two RHS with weights 2 and 3
3. Multiple lines: "?foo => ?bar ; ?baz => ?qux" adds rules across multiple lines
"""
function add_rule!(g::GrammarBuilder, rule::String)
    # Split multiple rules separated by semicolons
    # Split multiple rules separated by semicolons or newlines
    for rule_part in split(rule, ";")
        rule_part = strip(rule_part)
        isempty(rule_part) && continue
        
        # Parse LHS => RHS
        @assert occursin("=>", rule_part) "Rule must contain => but didn't find it in $rule_part"
        lhs, rhs = split(rule_part, "=>")
        lhs = strip(lhs)

        if startswith(lhs, "??")
            @assert !haskey(g.rules, lhs[2:end]) "LHS $(lhs[3:end]) used with ?? in some places and ? in others"
        elseif startswith(lhs, "?")
            @assert !haskey(g.rules, "?" * lhs) "LHS $(lhs[2:end]) used with ? in some places and ?? in others"
        else
            error("Unexpected LHS, doesn't start with `?` or `??`: $lhs")
        end

        # Add to rules
        if !haskey(g.rules, lhs)
            g.rules[lhs] = Vector{Pair{String,Int}}()
        end
        
        # Split RHS alternatives
        for alt in split(rhs, "|")
            alt = strip(alt)
            
            # Parse weight if present
            parts = split(alt)
            if length(parts) > 1 && all(isdigit, parts[end])
                weight = parse(Int, pop!(parts))
                rhs_expr = join(parts, " ")
            else
                weight = 1
                rhs_expr = alt
            end
            push!(g.rules[lhs], strip(rhs_expr) => weight)
        end
    end
    g
end

# Define + operator to merge GrammarBuilders and handle string conversion
function Base.:+(g1::GrammarBuilder, g2::GrammarBuilder)
    result = GrammarBuilder()
    # Copy rules from g1
    for (lhs, rhss) in g1.rules
        result.rules[lhs] = copy(rhss) # shallow since Pair is immutable
    end
    # Merge rules from g2
    for (lhs, rhss) in g2.rules
        if !haskey(result.rules, lhs)
            result.rules[lhs] = Vector{Pair{String,Int}}()
        end
        append!(result.rules[lhs], rhss)
    end
    result
end

Base.:+(g::GrammarBuilder, rule::String) = g + GrammarBuilder(rule)
Base.:+(rule::String, g::GrammarBuilder) = GrammarBuilder(rule) + g

Base.:-(g::GrammarBuilder, rule::String) = remove_rule!(g, rule)

"""
Convert the GrammarBuilder to a Grammar with the given type mappings and size distribution
"""
function build(g::GrammarBuilder; size_dist=Geometric(0.5))

    sym_of_type = [lhs[2:end] => lhs for lhs in keys(g.rules) if !startswith(lhs, "??")] # int => ?int
    
    # Convert rules to format expected by Grammar constructor
    prods = []
    for (lhs, rhss) in g.rules
        rhs_vec = []
        for (rhs, weight) in rhss
            push!(rhs_vec, rhs => weight)
        end
        push!(prods, lhs => rhs_vec)
    end

    start_expr_of_type = Vector{Pair{String, String}}()
    
    Grammar(prods, sym_of_type, start_expr_of_type; size_dist=size_dist)
end

function Base.filter!(f, g::GrammarBuilder)
    for (lhs, rhss) in g.rules
        filter!(rhs_wt -> f(lhs, rhs_wt[1]), rhss)
    end
    g
end

function remove_rule!(g::GrammarBuilder, rhs::AbstractString; lhs=nothing, verbose=false, expect_one=true)
    count = 0
    filter!(g) do lhs_, rhs_expr
        res = occursin(rhs, rhs_expr) && (isnothing(lhs) || lhs == lhs_)
        count += res
        verbose && println("removed $lhs_ => $rhs_expr")
        !res
    end
    verbose && println("removed $count rules")
    expect_one && @assert count == 1 "$count rules removed by remove_rule!($rhs)"
    g
end