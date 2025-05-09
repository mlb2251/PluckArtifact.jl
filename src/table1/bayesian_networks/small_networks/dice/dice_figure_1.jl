



# @define "dice_figure_1_fn" """
# (Y (λ rec x n -> (case n of O => x | S => (λn ->
#         (let ((x2 (if x (flip 0.2) (flip 0.3))))
#             (rec x2 n))
# ))))
# """
# add_benchmark!("dice_figure_1", "pluck_default", PluckBenchmark("(dice_figure_1_fn (flip 0.5) 100)"))


function dice_figure_1(x, n)
    if n == 0
        x
    else
        x2 = @dice_ite if x
            flip(0.2)
        else
            flip(0.3)
        end
        dice_figure_1(x2, n-1)
    end
end


add_benchmark!("dice_figure_1", "dice_default", DiceBenchmark(() -> pr(dice_figure_1(flip(0.5), 100))))



