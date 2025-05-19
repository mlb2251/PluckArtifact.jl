
function make_uniform_nat(n)
    # Construct a nested sequence of coin flips that returns the expression in options[i] with probability 1/length(options).
    n == 0 && return parse_expr("0")
    rest = make_uniform_nat(n-1)
    return parse_expr("(if (flip $(1.0 / (n+1))) 0 $rest)")
end


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
    start = "(mapunit (λx -> $(nats ? "(randnat)" : "(make_random_digit)")) $length)"
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
    start = "(map (λx -> $(nats ? "(randnat)" : "(make_random_digit)")) \$xs)"
    grammar_start = "(map (λx -> ?int) \$xs)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("\$x", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function map_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(map (λact -> $randint) (take $randint \$xs))"
    grammar_start = "(map (λact -> ?int) (take ?int \$xs))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("\$act", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function scanl_unit_grammar(; length=10, nats=true, kwargs...)
    start = "(scanlunit (λacc x -> $(nats ? "(randnat)" : "(make_random_digit)")) 0 $length)"
    grammar_start = "(scanlunit (λacc x -> ?int) 0 $length)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("\$acc", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function scanl_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(scanlunit (λacc x -> $randint) 0 $randint)"
    grammar_start = "(scanlunit (λacc x -> ?int) 0 ?int)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("\$acc", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
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
    start = "(scanl (λacc x -> $(nats ? "(randnat)" : "(make_random_digit)")) 0 \$xs)"
    grammar_start = "(scanl (λacc x -> ?int) 0 \$xs)"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("\$acc", e) && occursin("\$x", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end

function scanl_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(scanl (λacc act -> $randint) 0 (take $randint \$xs))"
    grammar_start = "(scanl (λacc act -> ?int) 0 (take ?int \$xs))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("\$acc", e) && occursin("\$act", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_scanl_unit_grammar(; length=10, nats=true, kwargs...)
    start = "(map (λstate -> $(nats ? "(randnat)" : "(make_random_digit)")) (scanlunit (λacc x -> $(nats ? "(randnat)" : "(make_random_digit)")) 0 $length))"
    grammar_start = "(map (λstate -> ?int) (scanlunit (λacc x -> ?int) 0 $length))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("\$state", e) && occursin("\$acc", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


# anylength + geom noise
function hmm_simple(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    # noise = "(geom_fuel 0.5 5)" # "$randint"
    noise = "$randint"

    start = "(map (λstate -> (+ state $noise)) (scanlunit (λacc x -> $randint) 0 $randint))"
    grammar_start = "(map (λstate -> (+ ?int $noise)) (scanlunit (λacc x -> ?int) 0 ?int))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("\$state", e) && occursin("\$acc", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function map_scanl_unit_grammar_any_length(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(map (λstate -> $randint) (scanlunit (λacc x -> $randint) 0 $randint))"
    grammar_core = "(map (λstate -> ?int) (scanlunit (λacc x -> ?int) 0 ?int))"

    TaskDist(
        seq_grammar(start, grammar_core; nats, kwargs...),
        "unit",
        "list",
        "(Unit)",
        (e) -> occursin("\$state", e) && occursin("\$acc", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function map_scanl_int_grammar(; length=10, nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(map (λstate -> $randint) (scanl (λacc act -> $randint) 0 \$xs))"
    grammar_start = "(map (λstate -> ?int) (scanl (λacc act -> ?int) 0 \$xs))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand $length)",
        (e) -> occursin("\$state", e) && occursin("\$acc", e) && occursin("\$act", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end



function map_scanl_int_grammar_anylength(; nats=true, kwargs...)
    randint = nats ? "(randnat)" : "(make_random_digit)"
    start = "(map (λstate -> $randint) (scanl (λacc x -> $randint) 0 (take $randint \$xs)))"
    grammar_start = "(map (λstate -> ?int) (scanl (λacc x -> ?int) 0 (take ?int \$xs)))"

    TaskDist(
        seq_grammar(start, grammar_start; nats, kwargs...),
        "list",
        "list",
        "(fillrand 30)",
        (e) -> occursin("\$state", e) && occursin("\$acc", e) && occursin("\$x", e),
        (_, o) -> any(x -> x != o[1], o) # not all the same
    )
end


function seq_grammar(start::String, grammar_core::String; nats=true, lets=true, size_dist=Geometric(0.5))

    # lets=false

    # BAD BAD BAD
    # start = lets ? replace(start, "#1" => "#2") : start
    # grammar_core = lets ? replace(grammar_core, "#1" => "#2") : grammar_core


    synthesis_defs()
    @define map "(Y (λ rec f xs -> (case xs of Nil => (Nil) | Cons => (λhd tl -> (Cons (f hd) (rec f tl))))))"
    set_type!(:map, "(int -> int) -> list -> list")
    @define mapunit "(λ f n -> (map f (fill n (Unit))))"
    set_type!(:mapunit, "(unit -> int) -> int -> list")


    @define foldl """
        (Y (λrec f acc xs ->
            (case xs of Nil => acc
                      | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (rec f acc' tl)
                                ))
            )
        ))
    """
    set_type!(:foldl, "(int -> int -> int) -> int -> list -> int")
    @define scanl """
        (Y (λrec f acc xs ->
            (case xs of Nil => (Nil)
                    | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (Cons acc' (rec f acc' tl))
                                ))
            )
        ))
    """
    set_type!(:scanl, "(int -> int -> int) -> int -> list -> list")

    @define scanlunit "(λf init n -> (scanl f init (fill n (Unit))))"
    set_type!(:scanlunit, "(int -> unit -> int) -> int -> int -> list")

    @define app_int_int "(λ f x -> (f x))"
    set_type!(:app_int_int, "(int -> int) -> int -> int")

    @define letII "(λ x f -> (f x))"
    set_type!(:letII, "int -> (int -> int) -> int")

    prods = [
        "?core" => [grammar_core],
        "?lets" => ["(letII ?int (λk -> ?core))"],
        "?int" => ["?int_term" => 8, "?int_nonterm" => 2],
        "?int_term" => [
            (nats ? "(randnat)" : "(make_random_digit)"),
            "?const_or_var",
            "(letII ?int (λx -> ?int_nonterm))" => 0.2
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
        ],
        "?bool_nonterm" => [
            "(iseven ?int)",
            "(== ?int ?int)",
            "(> ?int ?int)",
        ],
    ]

    sym_of_type = [
        "list" => lets ? "?lets" : "?core",
        "int" => "?int",
        "bool" => "?bool",
    ]
    start_expr_of_type = [
        "list" => lets ? "(letII $(nats ? "(randnat)" : "(make_random_digit)") (λk -> $start))" : start,
    ]
    return Grammar(prods, sym_of_type, start_expr_of_type; size_dist=size_dist)
end

function synthesis_defs()
    @define "eq_nat" "(Y (λ rec m n -> (case m of O => (case n of O => true | S => (λ _ -> false)) | S => (λ mpred -> (case n of O => false | S => (λ npred -> (rec mpred npred)))))))"
    @define "my_and" "(λ x y -> (case x of True => y | False => false))"
    @define "same_len_list_eq" "(Y (λ rec xs ys -> (case xs of Nil => true | Cons => (λ xhd xtl -> (case ys of Cons => (λ yhd ytl -> (my_and (eq_nat xhd yhd) (rec xtl ytl))))))))"
    @define "my_list_eq" "(λ xs ys -> (my_and (eq_nat (length xs) (length ys)) (same_len_list_eq xs ys)))"
    @define "length_eq" "(λ xs ys -> (eq_nat (length xs) (length ys)))"
    @define "old_list_eq" "(Y (λ rec xs ys -> (case xs of Nil => (case ys of Nil => true | Cons => (λ _ _ -> false)) | Cons => (λ xhd xtl -> (case ys of Nil => false | Cons => (λ yhd ytl -> (my_and (eq_nat xhd yhd) (rec xtl ytl))))))))"

    # replace (make_random_digit) and randlistdigit (which implicitly replace make_random_list)
    # Note random_digit is a primop so it can't be replaced.
    # DIGITS = [parse_expr("$(a)") for a = '0':'9']
    # DEFINITIONS[:(make_random_digit)] = Pluck.Definition(:(make_random_digit), make_uniform(DIGITS), nothing, true)
    unif_nat = make_uniform_nat(9)
    DEFINITIONS[:(make_random_digit)] = Pluck.Definition(:(make_random_digit), parse_expr("(λ_ -> $unif_nat)"))
    @define "randlistdigit" "((Y (λ rec unit -> (if (flip 0.5) (Nil) (Cons (make_random_digit) (rec unit))))) (Unit))"

    # fill a list of given length with a given value
    @define "fill" "(Y (λ rec n val -> (case n of O => (Nil) | S => (λp -> (Cons val (rec p val))))))"
    @define "fillrand" "(Y (λ rec n -> (case n of O => (Nil) | S => (λp -> (Cons (make_random_digit) (rec p))))))"
end


set_type!(:inc, "int -> int")
set_type!(:dec, "int -> int")
set_type!(Symbol("+"), "int -> int -> int")
set_type!(Symbol("-"), "int -> int -> int")
set_type!(Symbol(">"), "int -> int -> bool")
set_type!(Symbol("iseven"), "int -> bool")
set_type!(Symbol("=="), "int -> int -> bool")
set_type!(Symbol("take"), "int -> list -> list")


function more_defs()
    synthesis_defs()
    @define map "(Y (λ rec f xs -> (case xs of Nil => (Nil) | Cons => (λhd tl -> (Cons (f hd) (rec f tl))))))"
    set_type!(:map, "(int -> int) -> list -> list")
    @define mapunit "(λ f n -> (map f (fill n (Unit))))"
    set_type!(:mapunit, "(unit -> int) -> int -> list")

    @define scanl """
        (Y (λrec f acc xs ->
            (case xs of Nil => (Nil)
                    | Cons => (λhd tl ->
                                (let (acc' (f acc hd))
                                    (Cons acc' (rec f acc' tl))
                                ))
            )
        ))
    """
    set_type!(:scanl, "(int -> int -> int) -> int -> list -> list")
    @define scanlunit "(λf init n -> (scanl f init (fill n (Unit))))"
    set_type!(:scanlunit, "(int -> unit -> int) -> int -> int -> list") 

    @define app_int_int "(λ f x -> (f x))"
    set_type!(:app_int_int, "(int -> int) -> int -> int")

    @define letII "(λ x f -> (f x))"
    set_type!(:letII, "int -> (int -> int) -> int")

end