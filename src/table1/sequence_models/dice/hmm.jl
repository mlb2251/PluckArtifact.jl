
function dice_hmm_example(N)

    function make_bool_list(n)
        n == 0 && return Dice.Nil(AnyBool)
        Dice.Cons(AnyBool, true, make_bool_list(n-1))
    end

    function hmm(z0, num_steps)

        if num_steps == 0
            return Dice.Nil(AnyBool)
        end

        z1 = @dice_ite if z0 
            flip(0.7)
        else
            flip(0.1)
        end

        x1 = @dice_ite if z1 
            flip(0.3)
        else
            flip(0.6)
        end

        return Dice.Cons(AnyBool, x1, hmm(z1, num_steps - 1))
    end
        
    function bool_lists_equal(l1::Dice.List{AnyBool}, l2::Dice.List{AnyBool})
        match(l1, [:Nil => () -> match(l2, [:Nil => () -> true, :Cons => (hd, tl) -> false]), :Cons => (x, xs) -> match(l2, [:Cons => (y, ys) -> (@dice_ite if (prob_equals(x, y)); bool_lists_equal(xs, ys); else; false; end), :Nil => () -> false])])
    end 

    return pr(bool_lists_equal(hmm(false, N), make_bool_list(N)))

end

add_benchmark!("hmm", "dice_default", DiceBenchmark(() -> dice_hmm_example(50)))
