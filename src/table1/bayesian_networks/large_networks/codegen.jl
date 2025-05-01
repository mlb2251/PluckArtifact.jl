

struct Variable
    name::Symbol
    domain::Vector{Symbol}
end

bitwidth(var::Variable) = ceil(Int, log2(length(var.domain)))

function mk_int(var::Variable, i::Int; use_int_dist=false)
    @assert use_int_dist
    @assert i > 0 && i <= length(var.domain)
    width = bitwidth(var)
    return "(mk_int @$width @$(i-1))"
end

function mk_int(var::Variable, val::Symbol; use_int_dist=false)
    if !use_int_dist
        return "($(val))"
    end
    idx = findfirst(==(val), var.domain)
    @assert idx !== nothing
    return mk_int(var, idx; use_int_dist=use_int_dist)
end

function mk_eq(var::Variable, x, y; use_int_dist=false)
    equality = use_int_dist ? "int_dist_eq" : "constructors_equal"
    return "($equality $x $y)"
end

struct ProbabilityStatement
    target::Symbol
    parents::Vector{Symbol}
    # For conditional probabilities, this is a Dict mapping parent combinations to probability vectors
    # For marginal probabilities, this is just a single probability vector
    probabilities::Union{Vector{Float64}, Dict{Vector{Symbol}, Vector{Float64}}}
end

function parse_bif(filename::String)
    variables = Dict{Symbol, Variable}()
    probabilities = Vector{ProbabilityStatement}()

    # Track unique domains to create type definitions
    domain_to_type = Dict{Vector{Symbol}, Symbol}()

    open(filename) do file
        content = read(file, String)
        # Remove comments and normalize whitespace
        content = replace(content, r"//.*$"m => "")
        content = replace(content, r"/\*.*?\*/"s => "")

        # Parse variable declarations
        for m in eachmatch(r"variable\s+(\w+)\s*\{\s*type\s+discrete\s*\[\s*(\d+)\s*\]\s*\{([^}]+)\}", content)
            name = Symbol(m[1])
            domain_size = parse(Int, m[2])
            # Add "Option" prefix to any domain values that start with numbers
            domain = [Symbol(startswith(strip(v), r"\d") ? "Option" * strip(v) : strip(v)) for v in split(m[3], ",")]
            # domain = [Symbol(strip(v)) for v in split(m[3], ",")]
            @assert length(domain) == domain_size

            variables[name] = Variable(name, domain)

            # If this is a new unique domain, create a type for it
            if !haskey(domain_to_type, domain)
                type_name = name  # Use first variable name as type name
                domain_to_type[domain] = type_name
                Pluck.define_type!(type_name, Dict(val => Symbol[] for val in domain))
            end
        end

        # Parse probability statements
        for m in eachmatch(r"probability\s*\(\s*(\w+)(?:\s*\|\s*([^)]+))?\s*\)\s*\{([^}]+)\}", content)
            target = Symbol(m[1])
            parents = isnothing(m[2]) ? Symbol[] : [Symbol(strip(p)) for p in split(m[2], ",")]
            prob_data = strip(m[3])

            if isempty(parents)
                # Parse marginal probability
                probs = parse_probability_table(prob_data)
                push!(probabilities, ProbabilityStatement(target, parents, probs))
            else
                # Parse conditional probability table
                cpt = Dict{Vector{Symbol}, Vector{Float64}}()
                for line in split(prob_data, ";")
                    line = strip(line)
                    isempty(line) && continue

                    # Parse parent values and corresponding probabilities
                    m = match(r"\((.*?)\)\s*(.*)", line)
                    parent_vals = [Symbol(startswith(strip(v), r"\d") ? "Option" * strip(v) : strip(v)) for v in split(m[1], ",")]

                    #parent_vals = [Symbol(strip(v)) for v in split(m[1], ",")]
                    probs = parse_probability_table(m[2])
                    cpt[parent_vals] = probs
                end
                push!(probabilities, ProbabilityStatement(target, parents, cpt))
            end
        end
    end

    return variables, probabilities
end
function parse_probability_table(str)
    # Remove "table" keyword if present and any extra whitespace
    str = replace(str, r"^\s*table\s+" => "")
    # Remove any semicolons and extra whitespace
    str = replace(str, r"[;\s]+" => "")
    str = strip(str)
    # Parse the comma-separated probabilities
    return [parse(Float64, p) for p in split(str, ",")]
end

function generate_bayes_net_code(variables::Dict{Symbol, Variable}, probabilities::Vector{ProbabilityStatement}, target_var::Symbol; outfile = nothing, use_int_dist=false)

    # Generate let bindings
    bindings = String[]
    seen_vars = Set{Symbol}()  # Track variables we've already processed
    for prob in probabilities
        # Skip if we've already processed this variable
        if prob.target in seen_vars
            continue
        end
        push!(seen_vars, prob.target)

        if isempty(prob.parents)
            # Marginal probability
            var = variables[prob.target]
            values = [mk_int(var, val; use_int_dist=use_int_dist) for val in var.domain]
            # add a new let binding for the target variable
            push!(bindings, "$(prob.target) $(Pluck.discrete(values, prob.probabilities))")
        else
            # Conditional probability
            expr = generate_conditional_distribution(prob, variables; use_int_dist=use_int_dist)
            push!(bindings, "$(prob.target) $expr")
        end
    end

    # Return the complete let expression with the return variable
    res = "(let ($(join(bindings, "\n      "))) $target_var)"
    if outfile !== nothing
        open(outfile, "w") do io
            write(io, res)
        end
    end
    return res
end


function generate_conditional_distribution(prob::ProbabilityStatement, variables::Dict{Symbol, Variable}; use_int_dist=false)
    # Handle single parent case directly
    if length(prob.parents) == 1
        parent = prob.parents[1]
        if use_int_dist
            # we build the dist for the last value first becuase it doesn't need an "if", it just sits in the last else branch
            last_val = variables[parent].domain[end]
            last_probs = prob.probabilities[[last_val]]
            last_values = [mk_int(variables[prob.target], val; use_int_dist=use_int_dist) for val in variables[prob.target].domain]
            expr = Pluck.discrete(last_values, last_probs)

            # loop over domain of parent "B" (all except last variable)
            # for each of these variables, we build a new if-statement and put the previous result in the else branch
            for val in reverse(variables[parent].domain[1:end-1])
                probs = prob.probabilities[[val]] # P(A|B=val)
                var = variables[prob.target]
                values = [mk_int(var, val; use_int_dist=use_int_dist) for val in var.domain]
                if_cond = mk_eq(variables[parent], parent, mk_int(variables[parent], val; use_int_dist=use_int_dist); use_int_dist=use_int_dist)
                then_br = Pluck.discrete(values, probs)
                expr = "(if $if_cond $then_br $expr)"
            end
            return expr
        else
            # this is the caseof version, instead of using int dists
            exprs = String[]
            for val in variables[parent].domain
                probs = prob.probabilities[[val]] # P(A|B=val)
                var = variables[prob.target]
                values = [mk_int(var, val; use_int_dist=use_int_dist) for val in var.domain]
                then_br = Pluck.discrete(values, probs)
                expr = "$val => $then_br"
                push!(exprs, expr)
            end
            expr = "(case $parent of $(join(exprs, " | ")))"
            return expr
        end
    end

    # For multiple parents, build from innermost to outermost
    # First, create a mapping of all parent value combinations to their probabilities
    parent_domains = [variables[p].domain for p in prob.parents]
    var = variables[prob.target]
    target_values = [mk_int(var, val; use_int_dist=use_int_dist) for val in var.domain]

    # Start with innermost expressions (the discrete distributions).
    current_exprs = Dict{Vector{Symbol}, String}()
    for parent_vals in Iterators.product(parent_domains...)
        parent_vals = collect(Symbol, parent_vals)
        probs = prob.probabilities[parent_vals]
        current_exprs[parent_vals] = Pluck.discrete(target_values, probs)
    end

    # We're trying to generate a probabilistic program representing P(A | B,C,D)
    # And we have mappings from concrete parent values to distributions on target values
    # (which we can reify with Pluck.discrete()).
    # Our approach is this: we first build an expression for P(A | B=b C=c D=d) and store it in current_exprs[bcd]
    # This is easy it's just Pluck.discrete() and generates a flipnest 
    # Then we generate an expression for P(A | B=b C=c) and store it in current_exprs[bc]. This expression 
    # is going to end up casing on D and the branches of the case will be the current_exprs[bcd] expression we got 
    # at the previous step.
    # We do this until we get P(A).

    # Work backwards through parents, wrapping in case expressions
    for parent_idx = length(prob.parents):-1:1
        parent = prob.parents[parent_idx]
        new_exprs = Dict{Vector{Symbol}, String}()

        # Group expressions by their shared parent prefixes.
        # So at the previous step we generated things like P(A | B=b C=c D=d)
        # and stored them in current_exprs[bcd]
        # Now we're generating P(A | B=b C=c) and we want to store it in new_exprs[bc]
        # We do this by finding all the entries in current_exprs that have b and c in their prefix
        # and storing them in prefix_groups[bc]
        prefix_groups = Dict{Vector{Symbol}, Vector{Tuple{Symbol, String}}}()
        for (parent_vals, expr) in current_exprs
            prefix = parent_vals[1:parent_idx-1]
            val = parent_vals[parent_idx]
            if !haskey(prefix_groups, prefix)
                prefix_groups[prefix] = Tuple{Symbol, String}[]
            end
            push!(prefix_groups[prefix], (val, expr))
        end

        # Create case expression for each group. So we'll case on the parent we're eliminating 
        # at this step, "d", and the branches will be the expressions we got in the previous step
        for (prefix, cases_list) in prefix_groups

            sort!(cases_list, by = t -> findfirst(==(t[1]), variables[parent].domain))
            _, expr = cases_list[end]
    
            if use_int_dist
                for (val, then_br) in reverse(cases_list[1:end-1])
                    if_cond = mk_eq(variables[parent], parent, mk_int(variables[parent], val; use_int_dist=use_int_dist); use_int_dist=use_int_dist)
                    expr = "(if $if_cond $then_br $expr)"
                end
            else
                exprs = String[]
                for (val, then_br) in cases_list
                    e = "$val => $then_br"
                    push!(exprs, e)
                end
                expr = "(case $parent of $(join(exprs, " | ")))"
            end

            new_exprs[prefix] = expr
        end

        current_exprs = new_exprs
    end

    # At the end, we should have a single expression
    @assert length(current_exprs) == 1
    return first(values(current_exprs))
end

function topological_sort(probabilities::Vector{ProbabilityStatement})
    remaining = copy(probabilities)
    sorted = ProbabilityStatement[]

    while !isempty(remaining)
        # Find all nodes with no parents in the remaining set
        no_parents = filter(p -> all(parent ∉ [r.target for r in remaining] for parent in p.parents), remaining)

        # If we can't find any nodes without parents, we have a cycle
        isempty(no_parents) && error("Cycle detected in Bayesian network")

        # Add these to sorted and remove from remaining
        append!(sorted, no_parents)
        filter!(p -> p ∉ no_parents, remaining)
    end

    return sorted
end

function remove_unused_vars(probabilities::Vector{ProbabilityStatement}, target::Symbol)
    # Find all variables that are parents of any probability statement
    relevant_vars = Set{Symbol}()
    worklist = Set{Symbol}([target])
    while !isempty(worklist)
        var = pop!(worklist)
        push!(relevant_vars, var)
        statement = findall(p -> p.target == var, probabilities)
        @assert length(statement) == 1
        statement = probabilities[first(statement)]
        for parent in statement.parents
            push!(worklist, parent)
        end
    end
    return filter(p -> p.target in relevant_vars, probabilities)
end