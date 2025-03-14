# S -> XX YY | YY XX
# XX -> aa | bb XX XX 
# YY -> cc | cc XX | cc S

function pcfg_defs()

    VTP.define_type!(:pcfg_grammar_symbol, Dict(:SS => Symbol[], :XX => Symbol[], :YY => Symbol[], :a => Symbol[], :b => Symbol[], :c => Symbol[]))

    @define "generate_pcfg_grammar" """
    (Y (λ generate symbol -> 
      (case symbol of 
        SS => (let (xgen (generate ( XX )) ygen (generate (YY)) order (flip 0.5))
          (if order (append xgen ygen) (append ygen xgen)))
        XX => (if (flip 0.5) (Cons (a) (Nil)) (Cons (b) (append (generate (XX)) (generate (XX)))))
        YY => (Cons (c) (if (flip 0.5) (Nil) (generate (if (flip 0.5) (XX) (SS)))))
      )
    ))
    """

    @define "generate_pcfg_grammar_fuel" """
    (Y (λ generate fuel symbol -> 
      (case fuel of
        S fuel => 
          (case symbol of 
            SS => (let (xgen (generate fuel ( XX )) ygen (generate fuel (YY)) order (flip 0.5))
                (if order (append xgen ygen) (append ygen xgen)))
            XX => (if (flip 0.5) (Cons (a) (Nil)) (Cons (b) (append (generate fuel (XX)) (generate fuel (XX)))))
            YY => (Cons (c) (if (flip 0.5) (Nil) (generate fuel (if (flip 0.5) (XX) (SS)))))
          )
      )
    ))
    """

    @define "symbol_equals" """
    (λ symbol1 symbol2 ->
      (case symbol1 of
        a => (case symbol2 of
          a => true
          b => false
          c => false)
        b => (case symbol2 of
          a => false
          b => true
          c => false)
        c => (case symbol2 of
          a => false
          b => false
          c => true)
      )
    )
    """

    @define "list_symbols_equal" """
    (Y (λ rec list1 list2 ->
      (case list1 of
        Nil => (case list2 of
          Nil => true
          Cons _ _ => false)
        Cons hd1 tl1 => (case list2 of
          Nil => false
          Cons hd2 tl2 => (and (symbol_equals hd1 hd2) (rec tl1 tl2)))
      )
    ))
    """
end

function make_string_from_julia_list(l)
    # l is a list of symbols :a, :b, :c
    # We want to return a string that looks like (Cons (a) (Cons (b) (Cons (c) (Nil))))
    result = ""
    for symbol in l
        result *= "(Cons ($symbol) "
    end
    result *= "(Nil)" * repeat(")", length(l))
    return result
end

# test_example_string = [:c, :c, :b, :a, :b, :b, :a, :b, :a, :a, :b, :b, :a, :a, :a, :a, :a]
test_example_string = [:c, :b, :b, :b, :a, :b, :b, :a, :b, :a, :b, :b, :a, :b, :a, :a, :a, :a, :a, :b, :a, :a, :a]
test_example_string_program = make_string_from_julia_list(test_example_string)


pcfg_query() = "(list_symbols_equal (generate_pcfg_grammar (SS)) $test_example_string_program)"


pcfg_example_enum() = lazy_enumerate("(list_symbols_equal (generate_pcfg_grammar (SS)) $test_example_string_program)"; disable_cache = true)

# @btime lazy_enumerate("(list_symbols_equal (generate_pcfg_grammar_fuel 2 (SS)) $test_example_string_program)")

function make_long_observation_string(n)
    result_prefix = ""
    result_suffix = ""
    # something of the form abababababab...bcbcbcbcbc with a c in the middle
    for i = 1:n
        result_prefix *= "(Cons (a) (Cons (b) "
        result_suffix *= "(Cons (b) (Cons (c) "
    end
    result_suffix *= "(Nil)" * repeat(")", 4n + 1)
    return result_prefix * "(Cons (c) " * result_suffix
end


pcfg_example_long(n) = "(list_symbols_equal (generate_dice_grammar (Start)) $(make_long_observation_string(n)))"
pcfg_example_long_fuel(n, fuel) = "(list_symbols_equal (generate_dice_grammar_fuel $fuel (Start)) $(make_long_observation_string(n)))"

# VTP.bdd_forward("(list_symbols_equal (generate_dice_grammar (Start)) (Cons (a) (Cons (b) (Cons (c) (Nil)))))")


function run_pcfg_bdd()
    pcfg_defs()
    @bbtime bdd_forward(pcfg_example_long(20))
end

function run_pcfg_lazy(; fuel = nothing, kwargs...)
    pcfg_defs()
    if isnothing(fuel)
        @bbtime lazy_enumerate(pcfg_example_long(20); $kwargs...)
    else
        @bbtime lazy_enumerate(pcfg_example_long_fuel(20, $fuel); $kwargs...)
    end
end

add_benchmark!("pcfg", "pluck_default", PluckBenchmark(pcfg_query(); pre=pcfg_defs))
add_benchmark!("pcfg", "pluck_strict_enum", PluckBenchmark(pcfg_query(); pre=pcfg_defs, skip=true))
