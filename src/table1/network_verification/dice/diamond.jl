
function diamond(s1)
    @dice_ite if flip(0.5)
        s1
    else
        @dice_ite if flip(0.0001)
            false
        else
            s1
        end
    end
end

iterate_diamond(s1, n) = n == 0 ? s1 : diamond(iterate_diamond(s1, n-1))

function dice_diamond()
    pr(iterate_diamond(true, 100))
end

add_benchmark!("diamond", "dice_default", DiceBenchmark(dice_diamond))