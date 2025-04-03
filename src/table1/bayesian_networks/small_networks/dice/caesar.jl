



module Caesar
    using Dice
    @inductive CaesarChar a_() b_() c_() d_()

    function random_key()
        @dice_ite if flip(0.25)
            a_()
        elseif flip(0.333333)
            b_()
        elseif flip(0.5)
            c_()
        else
            d_()
        end
    end

    function caesar_random_char()
        @dice_ite if flip(0.5)
            a_()
        elseif flip(0.5)
            b_()
        elseif flip(0.5)
            c_()
        else
            d_()
        end
    end

    function caesar_random_string(p, max_length)
        if max_length == 0
            return Dice.Nil(CaesarChar)
        else
            @dice_ite if flip(p)
                Dice.Cons(CaesarChar, caesar_random_char(), caesar_random_string(p, max_length - 1))
            else
                Dice.Nil(CaesarChar)
            end
        end
    end

    function rotateChar(key, char)
        match(key, [
            :a_ => () -> char,
            :b_ => () -> match(char, [:a_ => b_, :b_ => c_, :c_ => d_, :d_ => a_]),
            :c_ => () -> match(char, [:a_ => c_, :b_ => d_, :c_ => a_, :d_ => b_]),
            :d_ => () -> match(char, [:a_ => d_, :b_ => a_, :c_ => b_, :d_ => c_])])
    end

    function sendChar(key, observation)
        gen = caesar_random_char()
        enc = rotateChar(key, gen)
        d = prob_equals(enc, observation)
        return d
    end

    function run_caesar_inductive(n)
        key = random_key()
        d = true
        for i = 1:n
            d &= sendChar(key, c_())
        end

        pr(dice() do
            let _ = observe(d)
                key
            end
        end)

    end

end

add_benchmark!("caesar", "dice_default", DiceBenchmark(() -> Caesar.run_caesar_inductive(100)))