# Model of typos

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



function perturb_defs()
  CHAR_TYPE = VTP.define_type!(:Char, Dict(Symbol("$(a)_") => Symbol[] for a = 'a':'e'))
  CHARACTERS = [VTP.Construct(CHAR_TYPE, Symbol("$(a)_"), []) for a = 'a':'e']
  DEFINITIONS[:random_char] = VTP.Definition(:random_char, make_uniform(CHARACTERS), nothing, true)
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

  # When use_strict_order is true, the BDD does 
  # exploit opportunities for dynamic programming.
  # But performance still scales poorly...
  # I wonder if we are creating the same thunk
  # multiple times, in different execution paths.

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
              (append insertion (Cons c perturbed_cs)) 
              )))))
  """




  @define "perturb_fuel" """
  (Y (λ perturb_fuel fuel s -> 
      (case s of 
        Nil => (random_string_fuel fuel 0.99) 
      | Cons c cs => 
        (let (perturbed_cs (perturb_fuel fuel cs))
          (if (flip 0.99) 
              (append (random_string_fuel fuel 0.99) (Cons c perturbed_cs)) 
              perturbed_cs)))))
  """


  # note during artifact construction: this is the one we evaluated against
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
              (append insertion (Cons c perturbed_cs)) 
              )))))
  """

end
perturb_defs()

# spell_test = """(strings_eq 
#   (perturb (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))
#            (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))
# )
# """

# suspended_spell_test = """(suspended_list_eq (λ x y -> (constructors_equal x y)) 
#   (perturb (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))
#            (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))
# )
# """

# spell_test = """(strings_eq 
#     (perturb (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))))))
#              (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))))))
#     )
#     """

# suspended_spell_test = """(suspended_list_eq (λ x y -> (constructors_equal x y))  
#     (perturb (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))))))
#              (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))))))
#     )
#     """

# spell_test = """(strings_eq 
#   (perturb (Cons (a_) (Cons (a_) (Nil))))
#            (Cons (a_) (Nil))
# )
# """

# spell_test = """(strings_eq 
#   (perturb (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))))
#            (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))
# )
# """

# # Query to time
# spell_test = """(strings_eq 
#   (perturb (Cons (a_) (Cons (b_) (Cons (c_) (Cons (c_) (Cons (d_) (Cons (d_) (Nil))))))))
#            (Cons (a_) (Cons (b_) (Cons (c_) (Cons (d_) (Nil)))))
# )
# """

# spell_test = """(strings_eq 
#   (perturb (Cons (a_) (Cons (b_) (Cons (c_) (Cons (e_) (Cons (c_) (Cons (e_) (Cons (d_) (Cons (d_) (Nil)))))))))) 
#            (Cons (a_) (Cons (e_) (Cons (e_) (Cons (e_) (Cons (e_) (Cons (e_) (Nil)))))))
# )
# """

# suspended_spell_test = """(suspended_list_eq (λ x y -> (constructors_equal x y))  
#   (perturb (Cons (a_) (Cons (b_) (Cons (c_) (Cons (e_) (Cons (c_) (Cons (e_) (Cons (d_) (Cons (d_) (Nil)))))))))) 
#            (Cons (a_) (Cons (c_) (Cons (e_) (Cons (c_) (Cons (e_) (Nil))))))
# )
# """

# spell_test_fuel(fuel) = """(strings_eq 
#   (perturb_fuel $fuel (Cons (a_) (Cons (b_) (Cons (c_) (Cons (c_) (Cons (d_) (Cons (d_) (Nil))))))))
#            (Cons (a_) (Cons (b_) (Cons (c_) (Cons (d_) (Nil)))))
# )
# """

# spell_test_fuel(fuel) = """(strings_eq 
#   (perturb_fuel $fuel (Cons (a_) (Cons (b_) (Cons (c_) (Cons (e_) (Cons (c_) (Cons (e_) (Cons (d_) (Cons (d_) (Nil)))))))))) 
#            (Cons (a_) (Cons (e_) (Cons (e_) (Cons (e_) (Cons (e_) (Cons (e_) (Nil)))))))
# )
# """

# spell_test = """(strings_eq 
#     (perturb (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil)))))))))
#              (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (b_) (Cons (c_) (Nil))))))))
#     )
#     """


function run_spell_test_bdd(; kwargs...)
  perturb_defs()
  @bbtime bdd_forward(spell_test; state=$BDDEvalState(; $kwargs...))
end

function run_spell_test_lazy(; fuel=nothing, kwargs...)
  perturb_defs()
  if isnothing(fuel)
    @bbtime lazy_enumerate(spell_test; $kwargs...)
  else
    @bbtime lazy_enumerate(spell_test_fuel($fuel); $kwargs...)
  end
end



# run_spell_test_bdd()


# Other versions
@define "perturb" """
(Y (λ perturb s -> 
    (case s of 
      Nil => (random_string 0.99) 
    | Cons c cs => 
      (let (perturbed_cs (perturb cs))
        (if (flip 0.01) perturbed_cs
            (append (random_string 0.99) (Cons c perturbed_cs)))))))
"""

# worse version
@define "perturb" """
(Y (λ perturb s -> 
    (case s of 
      Nil => (random_string 0.99) 
    | Cons c cs => 
        (if (flip 0.99) 
            (append (random_string 0.99) (Cons c (perturb cs))) 
            (perturb cs)))))
"""

# Is dynamic programming still helpful in this version?
# from hello to yellow again...


# ab to bb
# delete a

# without DP: size 79
# with DP: size 29
# delete h (ello to yellow)
#   insert y, use e (llo to llow)
#     insert ϵ, use l (lo to low)
#       insert ϵ, use l (o to ow)
#         insert ϵ, use o (ϵ to w) 
#           insert w (done)
#         delete o (ϵ to ow)
#           insert ow (done)
#       delete l (o to low)
#         insert l, use o (ϵ to w) (seen! 1)
#         delete o (ϵ to low)
#           insert low (done)
#     insert l, use l (o to ow) (seen! 4)
#     delete l (lo to llow)
#       insert ϵ, use l (o to low) (seen! 4)
#       delete l (o to llow)
#         insert ll, use o (ϵ to w) (seen! 1)
#         delete o (ϵ to llow)
#           insert llow (done)
#   delete e (llo to yellow)
#     insert ye, use l (llo to llow) (seen! 27)
#     insert yel, use l (o to ow)    (seen! 4)
#     delete l (lo to yellow)
#       insert ye, use l (o to low) (seen! 4)
#       insert yel, use l (o to ow) (seen! 4)
#       delete l (o to yellow)
#         insert yell, use o (ϵ to w) (seen! 1)
#         delete o (ϵ to yellow)
#           insert yellow (done)

# Repeated subproblems show up because there are multiple ways to produce prefixes of the output string:
#  delete h, add y
#  delete he, add ye







@define "perturb" """
(Y (λ perturb s ->
  (case s of 
    Nil => (if (flip 0.01) (Cons random_char (perturb (Nil))) (Nil))
    Cons c cs => (if (flip 0.01) (perturb cs) (Cons (if (flip 0.01) random_char c) (perturb cs)))
  )
))
"""



# VTP.bdd_forward("""(strings_eq 
#   (perturb (Cons (a_) (Cons (b_) (Cons (c_) (Cons (c_) (Cons (d_) (Nil)))))))
#            (Cons (a_) (Cons (b_) (Cons (c_) (Cons (d_) (Nil)))))
# )
# """)




# VTP.bdd_forward("""(strings_eq 
#   (perturb (Cons (a_) (Cons (b_) (Cons (c_) (Cons (c_) (Cons (d_) (Nil)))))))
#            (Cons (a_) (Cons (b_) (Cons (c_) (Cons (d_) (Cons (e_) (Nil))))))
# )
# """)



@define "geometric" """
  (Y (λ geometric p -> (if (flip p) (O) (S (geometric p)))))
"""

# This one is much slower than the version below.
@define "perturb" """
(Y (λ perturb s ->
  (if (flip 0.01) 
    (Cons (geometric 0.05) (perturb s))
    (case s of 
      Nil => (Nil)
    | Cons c cs => (if (flip 0.01) (perturb cs) (Cons c (perturb cs)))
    )
  )
))
"""

# yellow from hello -- ideal dynamic programming solution. O((m+n)^2)
# -----------------------------
# insert y (ellow from hello)
#   insert e (llow from hello)
#     insert l (low from hello)
#       insert l (ow from hello)
#         insert o (w from hello)
#           insert w (ϵ from hello)
#             delete h (ϵ from ello)
#               delete e (ϵ from llo)
#                 delete l (ϵ from lo)
#                   delete l (ϵ from o)
#                     delete o (ϵ from ϵ)
#           delete h (w from ello)
#             insert w (ϵ from ello)    (seen!)
#             delete e (w from llo)
#               insert w (ϵ from llo)   (seen!)
#               delete l (w from lo) 
#                 insert w (ϵ from lo)  (seen!)
#                 delete l (w from o) 
#                   insert w (ϵ from o)  (seen!)
#                   delete o (w from ϵ)
#                     insert w (ϵ from ϵ)
#         delete h (ow from ello)
#           insert o (w from ello)     (seen!)
#           delete e (ow from llo)
#             insert o (w from llo)    (seen!)
#             delete l (ow from lo)
#               insert o (w from lo)    (seen!)
#               delete l (ow from o)
#                 keep o   (w from ϵ)    (seen!)
#                 insert o (w from o)    (seen!)
#                 delete o (ow from ϵ)
#                   insert o (w from ϵ)    (seen!)
#       delete h (low from ello)
#         insert l (ow from ello)    (seen!)
#         delete e (low from llo)
#           keep l (ow from lo)      (seen!)
#           insert l (ow from llo)   (seen!)
#           delete l (low from lo)
#             keep l (ow from o)     (seen!)
#             insert l (ow from lo)  (seen!)
#             delete l (low from o)
#               insert l (ow from o)    (seen!)
#               delete o (low from ϵ)
#                 insert l (ow from ϵ)    (seen!)
#     delete h (llow from ello)
#       insert l (low from ello)   (seen!)
#       delete e (llow from llo)
#         keep l (low from lo)     (seen!)
#         insert l (low from llo)   (seen!)
#         delete l (llow from lo)
#           keep l (low from o)     (seen!)
#           insert l (low from lo)    (seen!)
#           delete l (llow from o)
#             insert l (low from o)  (seen!)
#             delete o (low from ϵ)
#               insert l (ow from ϵ)    (seen!)
#   delete h (ellow from ello)
#     keep e (llow from llo)      (seen!)
#     insert e (llow from ello)   (seen!)
#     delete e (ellow from llo)
#       insert e (llow from llo) (seen!)
#       delete l (ellow from lo)
#         insert e (llow from lo) (seen!)
#         delete l (ellow from o)
#           insert e (llow from o) (seen!)
#           delete o (ellow from ϵ)
#             insert e (llow from ϵ) (seen!)
# delete h (yellow from ello)
#   insert y (ellow from ello)    (seen!)
#   delete e (yellow from llo)
#     insert y (ellow from llo)    (seen!)
#     delete l (yellow from lo)
#       insert y (ellow from lo)    (seen!)
#       delete l (yellow from o)
#         insert y (ellow from o)    (seen!)
#         delete o (yellow from ϵ)
#           insert y (ellow from ϵ)    (seen!)

# Is SMC helpful? What are the paths upon seeing the first character ("y")?
# y from hello
# insert y (hello)
# delete h (y from ello)
#   insert y (ello)
#   delete e (y from llo)
#     insert y (llo)
#     delete l (y from lo)
#       insert y (lo)
#       delete l (y from o)
#         insert y (o)
#         delete o (y from ϵ)
#           insert y (ϵ)





# abc -> bbc

# delete a: bc -> bbc
#   insert b, use b (c -> c)
#     insert -, use c (done)
#     delete c (- -> c)
#       insert c at end (done)
#   insert -, use b (c -> bc)
#     insert b, use c (done)
#     delete c (- -> bc)
#       insert bc (done)
#   delete b (c -> bbc)
#     insert bb, use c (done)
#     delete c (- -> bbc)
#       insert bbc (done)


# This one is much faster... but still exponential in the list lengths.
@define "perturb" """
(Y (λ perturb s ->
  (case s of 
    Nil => (if (flip 0.01) (Cons (geometric 0.05) (perturb (Nil))) (Nil))
    Cons c cs => (if (flip 0.01) (perturb cs) (Cons (if (flip 0.01) (geometric 0.05) c) (perturb cs)))
  )
))
"""

@define "nat_eq" """
(Y (λ nat_eq m n -> (case m of 
  O => (case n of O => true | S _ => false)
  S mpred => (case n of O => false | S npred => (nat_eq mpred npred))
)))
"""

@define "nat_lists_eq" """
(Y (λ nat_lists_eq l1 l2 -> (case l1 of 
  Nil => (case l2 of Nil => true | Cons _ _ => false)
  Cons c1 c2 => (case l2 of Nil => false | Cons c3 c4 => (and (nat_eq c1 c3) (nat_lists_eq c2 c4)))
)))
"""

# TODO: investigate performance -- this is quite slow.
# Exponential number of nodes in BDD?
# Best speed would come from DP-like solution; but more PCFG-like than HMM-like.
# But is there a variable ordering that makes this better? Seems important to share
# checking of the remainder of the list.
# VTP.bdd_forward("""(nat_lists_eq 
#   (perturb (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil)))))))
#            (Cons 5 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Cons 2 (Nil)))))))
# )
# """)

# VTP.bdd_forward("""(nat_lists_eq 
#   (perturb (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil)))))))
#            (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil))))))
# )
# """)

# VTP.bdd_forward("""(nat_lists_eq 
#   (perturb (Cons 2 (Cons (geometric 0.5) (Cons 3 (Cons 3 (Cons 1 (Nil)))))))
#            (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil))))))
# )
# """)

# VTP.bdd_forward("""(nat_lists_eq 
#   (perturb (Cons 1 (Cons 2 (Cons 3 (Cons 4 (Cons 5 (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil))))))))))))
#            (Cons 1 (Cons 2 (Cons 3 (Cons 4 (Cons 5 (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil)))))))))))
# )
# """)


# Both implementations are exponential in length of lists; old one is noticeably faster.
function run_example(l1, l2; old_implementation=false, record_json=false)
  l1_string = "(Cons " * join(l1, " (Cons ") * " (Nil))" * repeat(")", length(l1) - 1)
  l2_string = "(Cons " * join(l2, " (Cons ") * " (Nil))" * repeat(")", length(l2) - 1)

  if old_implementation
    constrain("(perturb $l1_string)", [], to_value(l2), EvalState(; eval_limit=1000000, record_json=record_json))
  else
    VTP.bdd_forward("""(nat_lists_eq 
  (perturb $l1_string)
           $l2_string
)
"""; record_json=record_json)
  end
end

function run_example(n; old_implementation=false, record_json=false)
  l1 = [rand(0:9) for _ = 1:n]
  l2 = [rand(0:9) for _ = 1:n]
  run_example(l1, l2, old_implementation=old_implementation, record_json=record_json)
end

# constrain("""(nat_lists_eq 
#   (perturb (Cons 2 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Nil)))))))
#            (Cons 5 (Cons 0 (Cons 3 (Cons 3 (Cons 1 (Cons 2 (Nil)))))))
# )
# """, [], true)


@define "perturb" """
(Y (λ perturb s -> 
    (case s of 
      Nil => (random_string 0.99) 
    | Cons c cs => 
      (let (perturbed_cs (perturb cs))
        (if (flip 0.99) 
            (append (random_string 0.99) (Cons c perturbed_cs)) 
            perturbed_cs)))))
"""








long_string_1 = "edccdadbedadbbacddbecaedddaabdccbadadeaecbadcacedbdeeaadadcbeadedbdaebccdaeaaadabecdcadebaddbbdbceea"
long_string_2 = "edddecbcadccbeecedbabbcbbcaeebeebaabddbcbcaccdaddceeddedddbabdabceceabaccbbbcbcacceceaecacdddbbdaedb"
n = 4
m = 5
function julia_string_to_expression(s)
  e = ""
  for char in s
    e *= "(Cons ($(char)_) "
  end
  e *= "(Nil)" * repeat(")", length(s))
  return e
end

string_editing_query() = "(strings_eq (perturb $(julia_string_to_expression(long_string_1[1:n]))) $(julia_string_to_expression(long_string_2[1:m])))"

add_benchmark!("string_editing", "pluck_default", PluckBenchmark(string_editing_query(); pre=perturb_defs))
add_benchmark!("string_editing", "pluck_lazy_enum", PluckBenchmark(string_editing_query(); pre=perturb_defs, skip=true))
add_benchmark!("string_editing", "pluck_strict_enum", PluckBenchmark(string_editing_query(); pre=perturb_defs, skip=true))