
function sorted_defs()

  @define "nats_equal" """
  (Y (λ rec m n -> (case m of 
    O => (case n of O => true | S npred => false)
    S mpred => (case n of O => false | S npred => (rec mpred npred)))
  ))
  """

  @define "nat_lists_equal" """
  (Y (λ rec xs ys -> (case xs of 
    Nil => (case ys of Nil => true | Cons yhd ytl => false)
    Cons xhd xtl => (case ys of Nil => false | Cons yhd ytl => (and (nats_equal xhd yhd) (rec xtl ytl))))))
  """

  @define "random_num_larger_than" """
  (λmin -> (+ (randnat) min))
  """

  @define "random_num_larger_than_fuel" """
  (Y (λ rec fuel min -> 
    (case fuel of
    S fuel =>
      (if (flip 0.5) 
        min 
        (S (rec fuel min))
      )
    )
  ))
  """

  @define "generate_sorted_list" """
  (Y (λ rec min -> (if (flip 0.5) (Nil) (let (m (random_num_larger_than min)) (Cons m (rec m))))))
  """

  @define "generate_sorted_list_fuel" """
  (Y (λ rec fuel fuel_num min ->
    (case fuel of
    S fuel =>
        (if (flip 0.5) (Nil) (let (m (random_num_larger_than_fuel fuel_num min)) (Cons m (rec fuel fuel_num m))))
    )
  ))
  """

end

function make_long_sorted_list(n, m = 0)
    if n == 0
        return "(Nil)"
    else
        return "(Cons $(m) $(make_long_sorted_list(n-1, m+1)))"
    end
end


generate_sorted_list_test(l; equality = "nat_lists_equal") = "($equality (generate_sorted_list (O)) $(make_list_from_julia_list(l)))"
generate_sorted_list_test_fuel(l, fuel, fuel_num) = "(nat_lists_equal (generate_sorted_list_fuel $fuel $fuel_num (O)) $(make_list_from_julia_list(l)))"

SORTED_LIST_INPUT = [0, 3, 7, 12, 13, 15, 16, 20]

sorted_list_query() = generate_sorted_list_test(SORTED_LIST_INPUT)
test_to_perform_fuel(fuel, fuel_num) = generate_sorted_list_test_fuel(SORTED_LIST_INPUT, fuel, fuel_num)

add_benchmark!("sorted_list", "pluck_default", PluckBenchmark(sorted_list_query(); pre=sorted_defs))
add_benchmark!("sorted_list", "pluck_strict_enum", PluckBenchmark(test_to_perform_fuel(9, 6); pre=sorted_defs, timeout=true))
