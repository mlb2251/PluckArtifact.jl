# Model of typos

function perturb_defs()

  function make_uniform(options)
    # Construct a nested sequence of coin flips that returns the expression in options[i] with probability 1/length(options).
    if length(options) == 1
      return options[1]
    else
      flip_scrutinee = PrimOp(FlipOp(), [ConstReal(1.0 / length(options))])
      constructors = [:True, :False]
      cases = Dict(:True => options[1], :False => make_uniform(options[2:end]))
      return CaseOf(flip_scrutinee, cases, constructors)
    end
  end

  CHAR_TYPE = Pluck.define_type!(:Char, Dict(Symbol("$(a)_") => Symbol[] for a = 'a':'e'))
  CHARACTERS = [Pluck.Construct(CHAR_TYPE, Symbol("$(a)_"), []) for a = 'a':'e']
  DEFINITIONS[:random_char] = Pluck.Definition(:random_char, make_uniform(CHARACTERS), nothing)
  @define "strings_eq" """
  (Y (λ strings_eq l1 l2 -> (case l1 of 
    Nil => (case l2 of Nil => true | Cons _ _ => false)
    Cons c1 c2 => (case l2 of Nil => false | Cons c3 c4 => (and (constructors_equal c1 c3) (strings_eq c2 c4)))
  )))
  """

  @define "random_string" """
  (Y (λ random_string p -> 
    (if (flip p)
      (Nil)
      (Cons random_char (random_string p))
    )
  ))
  """

  @define "random_string_fuel" """
  (Y (λ random_string_fuel fuel p ->
    (case fuel of
      S => ( λfuel -> 
        (if (flip p)
          (Nil)
          (Cons random_char (random_string_fuel fuel p))
        )
      )
    )
  ))
  """

  # @define "perturb_fuel" """
  # (Y (λ perturb_fuel fuel s -> 
  #     (case s of 
  #       Nil => (random_string_fuel fuel 0.99) 
  #     | Cons c cs => 
  #       (let (perturbed_cs (perturb_fuel fuel cs))
  #         (if (flip 0.99) 
  #             (append (random_string_fuel fuel 0.99) (Cons c perturbed_cs)) 
  #             perturbed_cs)))))
  # """

  @define "perturb_fuel" """
  (Y (λ perturb_fuel fuel s -> 
      (case s of 
        Nil => (random_string_fuel fuel 0.99) 
        Cons c cs => 
        (let 
          (do_delete (flip 0.01) 
           insertion (random_string_fuel fuel 0.99)
           perturbed_cs (perturb_fuel fuel cs))
          (if do_delete
              perturbed_cs
              (append insertion (Cons (if (flip 0.01) random_char c) perturbed_cs)) 
              )))))
  """

  # note during artifact construction: this is the one we're using
  @define "perturb" """
  (Y (λ perturb s -> 
      (case s of 
        Nil => (random_string 0.99) 
        Cons c cs => 
        (let 
          (do_delete (flip 0.01) 
           insertion (random_string 0.99)
           perturbed_cs (perturb cs))
          (if do_delete
              perturbed_cs
              (append insertion (Cons (if (flip 0.01) random_char c) perturbed_cs)) 
              )))))
  """

end
perturb_defs()

long_string_1 = "edccdadbedadbbacddbecaedddaabdccbadadeaecbadcacedbdeeaadadcbeadedbdaebccdaeaaadabecdcadebaddbbdbceea"
long_string_2 = "edddecbcadccbeecedbabbcbbcaeebeebaabddbcbcaccdaddceeddedddbabdabceceabaccbbbcbcacceceaecacdddbbdaedb"
function julia_string_to_expression(s)
  e = ""
  for char in s
    e *= "(Cons ($(char)_) "
  end
  e *= "(Nil)" * repeat(")", length(s))
  return e
end

string_editing_query(n, m) = "(strings_eq (perturb $(julia_string_to_expression(long_string_1[1:n]))) $(julia_string_to_expression(long_string_2[1:m])))"
string_editing_query_fuel(n, m) = "(strings_eq (perturb_fuel $(m+1) $(julia_string_to_expression(long_string_1[1:n]))) $(julia_string_to_expression(long_string_2[1:m])))"

add_benchmark!("string_editing", "pluck_default", PluckBenchmark(string_editing_query(4, 5); pre=perturb_defs))
add_benchmark!("string_editing", "pluck_strict_enum", PluckBenchmark(string_editing_query_fuel(4, 5); pre=perturb_defs, timeout=true))