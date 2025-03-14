function hmm_defs()

  @define "hmm" """
  (Y (λ rec z0 -> 
    (let (z1 (flip (if z0 0.7 0.1)))   
      (Cons (flip (if z1 0.3 0.6)) (rec z1)))))
  """

  @define "prefix_equals?" """
  (Y (λ rec xs ys -> 
    (case ys of Nil => true | 
                Cons yhd ytl => (case xs of Nil => false | 
                                            Cons xhd xtl => (and (constructors_equal xhd yhd) (rec xtl ytl))))))
  """

  @define "generate_observations" "(Y (λ rec n -> (case n of O => (Nil) | S => (λ npred -> (Cons (True) (rec npred))))))"

  @define "hmm_example" "(λ n -> (prefix_equals? (hmm (False)) (generate_observations n)))"
end

add_benchmark!("hmm", "pluck_default", PluckBenchmark("(hmm_example 50)"; pre=hmm_defs))
add_benchmark!("hmm", "pluck_strict_enum", PluckBenchmark("(hmm_example 50)"; pre=hmm_defs, skip=true))
add_benchmark!("hmm", "pluck_lazy_enum", PluckBenchmark("(hmm_example 50)"; pre=hmm_defs, skip=true))

