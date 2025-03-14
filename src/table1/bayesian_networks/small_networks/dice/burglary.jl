
# Burglary example
function dice_burglary_example()
    earthquake = flip(0.0001)
    burglary = flip(0.001)
    alarm = Dice.DistOr(earthquake, burglary)
    phoneWorking = @dice_ite if earthquake 
        flip(0.7)
    else
        flip(0.99)
    end
    maryWakes = @dice_ite if alarm 
        if earthquake 
            flip(0.8)
        else
            flip(0.6)
        end
    else
        flip(0.2)
    end
    called = Dice.DistAnd(maryWakes, phoneWorking)
    return pr(burglary, evidence = called)
end

add_benchmark!("burglary", "dice_default", DiceBenchmark(dice_burglary_example))