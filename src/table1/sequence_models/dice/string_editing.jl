@inductive PerturbChar a_() b_() c_() d_() e_()

function random_char()
    @dice_ite if flip(0.2)
        a_()
    elseif flip(0.25)
        b_()
    elseif flip(0.33333)
        c_()
    elseif flip(0.5)
        d_()
    else
        e_()
    end
end

function random_string(p, max_length)
    if max_length == 0
        return Dice.Nil(PerturbChar)
    else 
        @dice_ite if flip(p)
            Dice.Cons(PerturbChar, random_char(), random_string(p, max_length-1))
        else
            Dice.Nil(PerturbChar)
        end
    end
end

function list_append(l1, l2)
    match(l1, [:Nil => () -> l2, :Cons => (hd, tl) -> Dice.Cons(PerturbChar, hd, list_append(tl, l2))])
end

function perturb(s, fuel, max_insert_length)

  fuel == 0 && return s

  insertion = random_string(0.01, max_insert_length)

  match(s, [:Nil => () -> insertion, 
            :Cons => (hd, tl) -> let perturbed_tail = perturb(tl, fuel-1, max_insert_length); (@dice_ite if flip(0.99); list_append(insertion, Dice.Cons(PerturbChar, (@dice_ite if flip(0.01); random_char() ; else; hd; end), perturbed_tail)); else; perturbed_tail; end); end])

end


function list_symbols_equal(l1::Dice.List{PerturbChar}, l2::Dice.List{PerturbChar}, fuel::Int)
    fuel == 0 && return false
    match(l1, [:Nil => () -> match(l2, [:Nil => () -> true, :Cons => (hd, tl) -> false]), :Cons => (hd1, tl1) -> match(l2, [:Nil => () -> false, :Cons => (hd2, tl2) -> (@dice_ite if prob_equals(hd1, hd2); list_symbols_equal(tl1, tl2, fuel-1); else; false; end)])])
end

function make_string_for_perturb(s)
    if s == ""
        return Dice.Nil(PerturbChar)
    else
        chars = Dict(["a" => a_(), "b" => b_(), "c" => c_(), "d" => d_(), "e" => e_()])
        return Dice.Dice.Cons(PerturbChar, chars[s[1:1]], make_string_for_perturb(s[2:end]))
    end
end

long_string_1 = "edccdadbedadbbacddbecaedddaabdccbadadeaecbadcacedbdeeaadadcbeadedbdaebccdaeaaadabecdcadebaddbbdbceea"
long_string_2 = "edddecbcadccbeecedbabbcbbcaeebeebaabddbcbcaccdaddceeddedddbabdabceceabaccbbbcbcacceceaecacdddbbdaedb"

function perturb_example(n, m)
    before_string = make_string_for_perturb(long_string_1[1:n])
    after_string =  make_string_for_perturb(long_string_2[1:m])
    return pr(list_symbols_equal(perturb(before_string, n+1, m+1), after_string, max(n+1, m+1)))
end

dice_string_editing_query() = perturb_example(4, 5)

add_benchmark!("string_editing", "dice_default", DiceBenchmark(dice_string_editing_query))