function pcfg_defs()

    Pluck.define_type!(:pcfg_grammar_symbol, Dict(:SS => Symbol[], :XX => Symbol[], :YY => Symbol[], :a => Symbol[], :b => Symbol[], :c => Symbol[]))

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

function pcfg_query()
  test_example_string = [:c, :b, :b, :b, :a, :b, :b, :a, :b, :a, :b, :b, :a, :b, :a, :a, :a, :a, :a, :b, :a, :a, :a]
  test_example_string_program = make_string_from_julia_list(test_example_string)
  "(list_symbols_equal (generate_pcfg_grammar (SS)) $test_example_string_program)"
end

function pcfg_query_fuel()
  test_example_string = [:c, :b, :b, :b, :a, :b, :b, :a, :b, :a, :b, :b, :a, :b, :a, :a, :a, :a, :a, :b, :a, :a, :a]
  test_example_string_program = make_string_from_julia_list(test_example_string)
  "(list_symbols_equal (generate_pcfg_grammar_fuel 12 (SS)) $test_example_string_program)"
end

add_benchmark!("pcfg", "pluck_default", PluckBenchmark(pcfg_query(); pre=pcfg_defs))
add_benchmark!("pcfg", "pluck_strict_enum", PluckBenchmark(pcfg_query_fuel(); pre=pcfg_defs, timeout=true))
