
function ladder(i1, i2)
    output = flip(0.5)
    result = (output, !output)
    fail_result = (false, false)
    @dice_ite if i1
        @dice_ite if flip(0.001)
            fail_result
        else
            result
        end
    else
        @dice_ite if i2
            result
        else
            fail_result
        end
    end
end

function iterate_ladder(i1, i2, n) 
    n == 0 ? (i1, i2) : ladder(iterate_ladder(i1, i2, n-1)...)
end

function dice_ladder()
    pr(iterate_ladder(true, false, 100))
end

add_benchmark!("ladder", "dice_default", DiceBenchmark(dice_ladder))