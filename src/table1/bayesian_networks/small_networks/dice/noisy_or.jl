function dice_noisy_or_example()
    n0 = flip(0.5)
    n4 = flip(0.5)
    n1 = @dice_ite if n0 
        flip(0.8)
    else
        flip(0.1)
    end

    n21 = @dice_ite if n0 
        flip(0.8)
    else
        flip(0.1)
    end

    n22 = @dice_ite if n4 
        flip(0.8)
    else
        flip(0.1)
    end

    n33 = @dice_ite if n4 
        flip(0.8)
    else
        flip(0.1)
    end

    n2 = Dice.DistOr(n21, n22)

    n31 = @dice_ite if n1 
        flip(0.8)
    else
        flip(0.1)
    end

    n32 = @dice_ite if n2 
        flip(0.8)
    else    
        flip(0.1)
    end

    n3 = Dice.DistOr(n31, Dice.DistOr(n32, n33))

    return pr(n3)
end

add_benchmark!("noisy_or", "dice_default", DiceBenchmark(dice_noisy_or_example))