function grammar_of_task(task)
    Dict(
        "cIID-Gen" => map_unit_grammar_any_length,
        "cIID-IO" => map_int_grammar_anylength,
        "Markov-Gen" => scanl_unit_grammar_any_length,
        "Markov-IO" => scanl_int_grammar_anylength,
        "HMM-Gen" => map_scanl_unit_grammar_any_length,
        "HMM-Gen-IO" => map_scanl_int_grammar_anylength,
    )[task](;nats=true, lets=true)
end

function default_input_dist(input_type::String)
    Dict(
        "list" => "(fillrand $(make_uniform_nat(6)))",
        "int" => "(make_random_digit)",
        "bool" => "(flip 0.5)",
        "unit" => "(Unit)",
    )[input_type]
end


function map_unit_grammar(; length=10, nats=true, kwargs...)
    start = "(mapunit (λx -> $(nats ? "randnat" : "make_random_digit")) $length)"
    grammar_start = "(mapunit (λx -> ?int) $length)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (_) -> true,
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function map_int_grammar(; length=10, nats=true, kwargs...)
    start = "(map (λx -> $(nats ? "randnat" : "make_random_digit")) #1)"
    grammar_start = "(map (λx -> ?int) #1)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("x#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function map_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(map (λact -> $randint) (take $randint #1))"
    grammar_start = "(map (λact -> ?int) (take ?int #1))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("act#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function scanl_unit_grammar(; length=10, nats=true, kwargs...)
    start = "(scanlunit (λacc x -> $(nats ? "randnat" : "make_random_digit")) 0 $length)"
    grammar_start = "(scanlunit (λacc x -> ?int) 0 $length)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("acc#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function scanl_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(scanlunit (λacc x -> $randint) 0 $randint)"
    grammar_start = "(scanlunit (λacc x -> ?int) 0 ?int)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("acc#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(mapunit (λx -> $randint) $randint)"
    grammar_core = "(mapunit (λx -> ?int) ?int)"

    TaskDist(
        seq_grammar(start, grammar_core; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> true,
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function scanl_int_grammar(; length=10, nats=true, kwargs...)
    start = "(scanl (λacc x -> $(nats ? "randnat" : "make_random_digit")) 0 #1)"
    grammar_start = "(scanl (λacc x -> ?int) 0 #1)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("acc#", e) && occursin("x#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function scanl_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(scanl (λacc act -> $randint) 0 (take $randint #1))"
    grammar_start = "(scanl (λacc act -> ?int) 0 (take ?int #1))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("acc#", e) && occursin("act#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_scanl_unit_grammar(; length=10, nats=true, kwargs...)
    start = "(map (λstate -> $(nats ? "randnat" : "make_random_digit")) (scanlunit (λacc x -> $(nats ? "randnat" : "make_random_digit")) 0 $length))"
    grammar_start = "(map (λstate -> ?int) (scanlunit (λacc x -> ?int) 0 $length))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("state#", e) && occursin("acc#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


# anylength + geom noise
function hmm_simple(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    # noise = "(geom_fuel 0.5 5)" # "$randint"
    noise = "$randint"

    start = "(map (λstate -> (+ state $noise)) (scanlunit (λacc x -> $randint) 0 $randint))"
    grammar_start = "(map (λstate -> (+ ?int $noise)) (scanlunit (λacc x -> ?int) 0 ?int))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("state#", e) && occursin("acc#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_scanl_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(map (λstate -> $randint) (scanlunit (λacc x -> $randint) 0 $randint))"
    grammar_core = "(map (λstate -> ?int) (scanlunit (λacc x -> ?int) 0 ?int))"

    TaskDist(
        seq_grammar(start, grammar_core; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("state#", e) && occursin("acc#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function map_scanl_int_grammar(; length=10, nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(map (λstate -> $randint) (scanl (λacc act -> $randint) 0 #1))"
    grammar_start = "(map (λstate -> ?int) (scanl (λacc act -> ?int) 0 #1))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("state#", e) && occursin("acc#", e) && occursin("act#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function map_scanl_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "randnat" : "make_random_digit"
    start = "(map (λstate -> $randint) (scanl (λacc x -> $randint) 0 (take $randint #1)))"
    grammar_start = "(map (λstate -> ?int) (scanl (λacc x -> ?int) 0 (take ?int #1)))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("state#", e) && occursin("acc#", e) && occursin("x#", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function seq_grammar(start::String, grammar_core::String; nats=true, lets=true, size_dist=Geometric(0.5))

    # BAD BAD BAD
    start = lets ? replace(start, "#1" => "#2") : start
    grammar_core = lets ? replace(grammar_core, "#1" => "#2") : grammar_core


    Pluck.synthesis_defs()
    @define map "(int -> int) -> list -> list" "(Y (λ rec f xs -> (case xs of Nil => (Nil) | Cons => (λhd tl -> (Cons (f hd) (rec f tl))))))"
    @define mapunit "(unit -> int) -> int -> list" "(λ f n -> (map f (fill n (Unit))))"
    @define "bool_and" "bool -> bool -> bool" "(λ x y -> (case x of True => y | False => false))"
    @define "bool_or" "bool -> bool -> bool" "(λ x y -> (case x of True => true | False => y))"
    @define "bool_xor" "bool -> bool -> bool" "(λ x y -> (case x of True => (not y) | False => y))"


    # @define fold "(Y (λrec xs init f -> (case xs of Nil => init | Cons => (λhd tl -> (f hd (rec tl init f))))))"
    @define foldl "(int -> int -> int) -> int -> list -> int" """
        (Y (λrec f acc xs ->
            (case xs of Nil => acc
                      | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (rec f acc' tl)
                                ))
            )
        ))
    """
    @define scanl "(int -> int -> int) -> int -> list -> list" """
        (Y (λrec f acc xs ->
            (case xs of Nil => (Nil)
                    | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (Cons acc' (rec f acc' tl))
                                ))
            )
        ))
    """

    @define scanlunit "(int -> unit -> int) -> int -> int -> list" "(λf init n -> (scanl f init (fill n (Unit))))"

    @define app_int_int "(int -> int) -> int -> int" "(λ f x -> (f x))"
    @define letII "int -> (int -> int) -> int" "(λ x f -> (f x))"

    prods = [
        # "?list" => ["(map (λx -> ?int) (fill $length 0))"],
        # "?list" => ["(mapunit (λx -> ?int) $length)"],

        "?core" => [grammar_core],
        "?lets" => ["(letII ?int (λk -> ?core))"],
        "?int" => ["?int_term" => 8, "?int_nonterm" => 2],
        "?int_term" => [
            (nats ? "randnat" : "make_random_digit"),
            "?const_or_var",
            "(letII ?int (λx -> ?int_nonterm))" => 0.2
            # "(app_int_int (λx -> ?int_nonterm) ?int)" => 0.2
        ],
        "?const_or_var" => [
            "#int",
            "?constint" => 0.3
        ],
        "?constint" => [("$i" for i ∈ 0:9)...],
        "?int_nonterm" => [
            "(inc ?int)",
            "(+ ?int ?int)",
            "(- ?int ?int)",
            "(case ?int of O => ?int | S => (λn -> ?int))",
            "(if ?bool ?int ?int)",
        ],
        "?bool" => ["?bool_term" => 8, "?bool_nonterm" => 2],
        "?bool_term" => [
            "#bool",
            ["(flip 0.$i)" for i in 1:9]...,
            # "true",
            # "false"
        ],
        "?bool_nonterm" => [
            # "(bool_and ?bool ?bool)",
            # "(bool_or ?bool ?bool)",
            # "(bool_xor ?bool ?bool)",
            # "(not ?bool)",
            # "(if ?bool ?bool ?bool)",
            "(iseven ?int)",
            "(== ?int ?int)",
            "(> ?int ?int)",
            # "(case ?int of O => ?bool | S => (λn -> ?bool))",
        ],
    ]

    sym_of_type = [
        "list" => lets ? "?lets" : "?core",
        "int" => "?int",
        "bool" => "?bool",
    ]
    start_expr_of_type = [
        # "list" => "(mapunit (λx -> make_random_digit) $length)",
        "list" => lets ? "(letII $(nats ? "randnat" : "make_random_digit") (λk -> $start))" : start,
        # "list" => "(map (λx -> make_random_digit) (fill $length 0))",
    ]
    return Grammar(prods, sym_of_type, start_expr_of_type; size_dist=size_dist)
end

function more_defs()
    Pluck.synthesis_defs()
    @define map "(int -> int) -> list -> list" "(Y (λ rec f xs -> (case xs of Nil => (Nil) | Cons => (λhd tl -> (Cons (f hd) (rec f tl))))))"
    @define mapunit "(unit -> int) -> int -> list" "(λ f n -> (map f (fill n (Unit))))"
    @define "bool_and" "bool -> bool -> bool" "(λ x y -> (case x of True => y | False => false))"
    @define "bool_or" "bool -> bool -> bool" "(λ x y -> (case x of True => true | False => y))"
    @define "bool_xor" "bool -> bool -> bool" "(λ x y -> (case x of True => (not y) | False => y))"


    # @define fold "(Y (λrec xs init f -> (case xs of Nil => init | Cons => (λhd tl -> (f hd (rec tl init f))))))"
    @define foldl "(int -> int -> int) -> int -> list -> int" """
        (Y (λrec f acc xs ->
            (case xs of Nil => acc
                    | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (rec f acc' tl)
                                ))
            )
        ))
    """
    @define scanl "(int -> int -> int) -> int -> list -> list" """
        (Y (λrec f acc xs ->
            (case xs of Nil => (Nil)
                    | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (Cons acc' (rec f acc' tl))
                                ))
            )
        ))
    """

    @define scanlunit "(int -> unit -> int) -> int -> int -> list" "(λf init n -> (scanl f init (fill n (Unit))))"

    @define app_int_int "(int -> int) -> int -> int" "(λ f x -> (f x))"
    @define letII "int -> (int -> int) -> int" "(λ x f -> (f x))"

end