function find_matching_paren(str, start=2)
    count = 1
    i = start
    while count > 0 && i <= length(str)
        if str[i] == '('
            count += 1
        elseif str[i] == ')'
            count -= 1
        end
        i += 1
    end
    return i - 1
end

function parse_if_structure(str)
    # println("Parsing if structure: '$(str)'")
    # Skip "if " and find the condition
    str = str[4:end]
    if !startswith(str, "(")
        error("Expected '(' after 'if' in: $str")
    end
    
    # Find the matching parenthesis for condition
    cond_end = find_matching_paren(str)
    condition = str[2:cond_end-1]  # Remove outer parentheses
    # println("Extracted condition: '$(condition)'")
    
    # Skip to "then"
    str = strip(str[cond_end+1:end])
    if !startswith(str, "then")
        error("Expected 'then' after condition in: $str")
    end
    str = strip(str[5:end])  # Skip "then"
    
    if !startswith(str, "(")
        error("Expected '(' after 'then' in: $str")
    end
    
    # Find the matching parenthesis for then part
    then_end = find_matching_paren(str)
    then_part = str[2:then_end-1]  # Remove outer parentheses
    # println("Extracted then part: '$(then_part)'")
    
    # Skip to "else"
    str = strip(str[then_end+1:end])
    if !startswith(str, "else")
        error("Expected 'else' after then part in: $str")
    end
    str = strip(str[5:end])  # Skip "else"
    
    if !startswith(str, "(")
        error("Expected '(' after 'else' in: $str")
    end
    
    # The rest is the else part (minus the outer parentheses)
    else_part = str[2:end-1]
    # println("Extracted else part: '$(else_part)'")
    
    return (condition, then_part, else_part)
end

function parse_expression(str)
    # println("\nParse expression input: '$(str)'")
    str = strip(str)
    
    # Then check for if-then-else structure first
    if startswith(str, "if")
        # println("Found if statement")
        condition, then_part, else_part = parse_if_structure(str)
        
        # Recursively parse each part
        condition = parse_expression(condition)
        then_part = parse_expression(then_part)
        else_part = parse_expression(else_part)
        
        result = "ifelse($condition, $then_part, $else_part)"
        # println("Created ifelse: '$(result)'")
        return result
    end
    
    # Handle int comparisons
    if occursin(r"\w+\s*==\s*int\(\d+,\s*\d+\)", str)
        # println("Found int comparison")
        str = replace(str, r"(\w+)\s*==\s*int\((\d+),\s*(\d+)\)" => s"prob_equals(\1, DistUInt{\2}(\3))")
        # println("Converted comparison: '$(str)'")
    end
    
    # Handle discrete function calls
    if occursin(r"discrete\(", str)
        # println("Found discrete call")
        str = replace(str, r"discrete\(([\d\.,\s]+)\)" => function(m)
            numbers_str = replace(m, r"discrete\((.*)\)" => s"\1")
            numbers = parse.(Float64, split(numbers_str, ','))
            n = ceil(Int, log2(length(numbers)))
            result = "discrete(DistUInt{$n}, [$(join(numbers, ","))])"
            # println("Converted discrete: '$(result)'")
            return result
        end)
    end
    
    # println("Returning: '$(str)'")
    return str
end

function convert_dice_code(name, infile::String, outfile::String, target_var)
    @assert endswith(outfile, ".jl.ignore")
    @assert endswith(infile, ".dice")

    input = open(infile) do f
        read(f, String)
    end

    # Split into lines
    lines = split(input, '\n')
    
    # Process each line, keeping empty lines
    converted_lines = map(lines) do line
        # println("\nProcessing line: '$(line)'")
        if isempty(strip(line))
            return line
        end
        
        # Handle let/in structure
        if startswith(strip(line), "let")
            # println("Found let expression")
            # Extract variable name and expression
            m = match(r"let\s+(\w+)\s*=\s*(.+)\s+in$", line)
            if m !== nothing
                var_name = m[1]
                expr = strip(m[2])
                # println("Var name: '$(var_name)'")
                # println("Expression: '$(expr)'")
                result = "$(var_name) = $(parse_expression(expr))"
                # println("Converted let: '$(result)'")
                return result
            end
        end
        
        # If not a let/in structure, parse the whole line
        parse_expression(line)
    end
    
    result = join(converted_lines, "\n    ")
    

    result = """
    using Dice
    import PluckArtifact: @bbtime

    println("Defining Julia function for $name...")
    function $name()
        $result
        return pr($target_var)
    end

    print("Warmup...")
    $name();

    println("Benchmarking...")
    res, timing = @bbtime $name();
    println("Result: Dict(")
    for (val, prob) in res
        println("  \$val => \$prob,")
    end
    println(")")
    println("Time: ", timing)
    """

    # Write to file
    open(outfile, "w") do io
        write(io, result)
    end
    
    return result
end