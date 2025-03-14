

function gen_sorted_nat(min_val, fuel)
    fuel == 0 && return min_val
    @dice_ite if flip(0.5)
        min_val
    else
        Nat.S(gen_sorted_nat(min_val, fuel-1))
    end
end

function gen_sorted_list(max_size, min_val, fuel)
    max_size == 0 && return Dice.Nil(Nat.t)
    @dice_ite if flip(0.5)
        Dice.Nil(Nat.t)
    else
        let hd = gen_sorted_nat(min_val, fuel)
            Dice.Cons(Nat.t, hd, gen_sorted_list(max_size-1, hd, fuel))
        end
    end
end

function nats_equal(n1::Nat.t, n2::Nat.t)
    match(n1, [
        :Z => () -> match(n2, [:Z => () -> true, :S => (n2pred) -> false]),
        :S => (n1pred) -> match(n2, [:S => (n2pred) -> nats_equal(n1pred, n2pred), :Z => () -> false]),
    ])
end

function lists_equal(l1::Dice.List{Nat.t}, l2::Dice.List{Nat.t})
    match(l1, [
        :Nil => () -> match(l2, [:Nil => () -> true, :Cons => (hd, tl) -> false]),
        :Cons => (x, xs) -> match(l2, [:Cons => (y, ys) -> (@dice_ite if (nats_equal(x, y)); lists_equal(xs, ys); else; false; end), :Nil => () -> false]),
    ])
end


make_nat(n) = if n == 0; Nat.Z(); else Nat.S(make_nat(n-1)); end

make_list(l) = if isempty(l); Dice.Nil(Nat.t); else Dice.Cons(Nat.t, make_nat(l[1]), make_list(l[2:end])); end

l = [0, 3, 7, 12, 13, 15, 16, 20]
test_list = make_list(l);
sorted_list_dice() = pr(lists_equal(gen_sorted_list(9, Nat.Z(), 6), make_list(l)))

add_benchmark!("sorted_list", "dice_default", DiceBenchmark(sorted_list_dice))