

dice_figure_1_ex = """
(let ((x (flip 0.5))
     (y (if x (flip 0.2) (flip 0.3)))
     (z (if y (flip 0.2) (flip 0.3))))
     z
)
"""

function dice_fig1_defs()
    @define "dice_figure_1_fn" """
    (Y (λ rec x n -> (case n of O => x | S => (λn ->
            (let ((x2 (if x (flip 0.2) (flip 0.3))))
                (rec x2 n))
    ))))
    """
end

# println("AAYYYY")

# add_benchmark!("dice_figure_1", "pluck_default", PluckBenchmark("(dice_figure_1_fn (flip 0.5) 100)"; pre=dice_fig1_defs))
add_benchmark!("dice_figure_1", "pluck_default", PluckBenchmark("(dice_figure_1_fn (flip 0.5) 100)"; pre=dice_fig1_defs))
add_benchmark!("dice_figure_1", "pluck_lazy_enum", PluckBenchmark("(dice_figure_1_fn (flip 0.5) 100)"; pre=dice_fig1_defs, timeout=true))
add_benchmark!("dice_figure_1", "pluck_strict_enum", PluckBenchmark("(dice_figure_1_fn (flip 0.5) 100)"; pre=dice_fig1_defs, timeout=true))









