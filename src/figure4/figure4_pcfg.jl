# Generate a string from the PCFG and track how much fuel is needed to make it.
function generate_long_string(n, start_symbol)
    if start_symbol == :SS
        first_string, fuel_1 = generate_long_string(n // 2, :XX)
        second_string, fuel_2 = generate_long_string(n - length(first_string), :YY)
        return (rand() < 0.5 ? [first_string..., second_string...] : [second_string..., first_string...]), fuel_1 + fuel_2 + 1
    elseif start_symbol == :XX
        if n <= 1
            return [:a], 0
        else
            s1, fuel_1 = generate_long_string((n - 1) // 2, :XX)
            s2, fuel_2 = generate_long_string(n - length(s1), :XX)
            return [:b, s1..., s2...], fuel_1 + fuel_2 + 1
        end
    else
        if n <= 1
            return [:c], 0
        elseif rand() < 0.5
            s, fuel_1 = generate_long_string(n - 1, :XX)
            return [:c, s...], fuel_1 + 1
        else
            s, fuel_1 = generate_long_string(n - 1, :SS)
            return [:c, s...], fuel_1 + 1
        end
    end
end


function pcfg_inputs_from_approximate_sizes(approximate_sizes)
    input_strings = [(generate_long_string(n, :SS)) for n in approximate_sizes]
    inputs = [s for (s, fuel) in input_strings]
    input_sizes = [length(s) for (s, fuel) in input_strings]
    fuels = [fuel for (s, fuel) in input_strings]
    return inputs, input_sizes, fuels
end


pcfg_dice_inputs = Dict{Symbol, Any}(
    :inputs => [[:c, :a], [:a, :c], [:c, :b, :a, :a], [:c, :b, :a, :a], [:b, :a, :b, :a, :a, :c], [:c, :b, :a, :b, :a, :a], [:c, :a, :b, :b, :a, :a, :a], [:b, :b, :a, :a, :a, :c, :a, :c], [:c, :a, :b, :b, :a, :a, :b, :a, :a], [:c, :a, :c, :b, :b, :a, :a, :b, :a, :a], [:b, :b, :b, :a, :a, :b, :a, :a, :b, :a, :b, :a, :a, :c, :b, :a, :b, :a, :a, :c], [:c, :b, :b, :a, :b, :a, :a, :b, :a, :a, :b, :b, :b, :a, :a, :b, :a, :a, :b, :b, :a, :a, :a], [:b, :b, :b, :a, :a, :b, :a, :a, :b, :b, :a, :a, :a, :c, :b, :b, :a, :a, :a, :c, :c, :a], [:c, :c, :c, :a, :b, :b, :a, :a, :a, :b, :b, :b, :a, :b, :a, :a, :a, :b, :b, :a, :a, :b, :a, :a], [:c, :b, :b, :a, :a, :a, :c, :c, :a, :b, :b, :b, :a, :b, :a, :a, :a, :b, :b, :a, :a, :b, :a, :a], [:b, :b, :b, :a, :b, :a, :a, :a, :b, :b, :a, :b, :a, :a, :a, :c, :c, :a, :c, :b, :b, :a, :a, :b, :a, :a]],
    :input_sizes => [2, 2, 4, 4, 6, 6, 7, 8, 9, 10, 20, 23, 22, 24, 24, 26],
    :fuels => [1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 11, 12, 13, 14, 14, 15]
)


function get_dice_inputs_pcfg()
    !isempty(pcfg_dice_inputs) && return pcfg_dice_inputs
    dice_approximate_sizes = [1:1:10..., 20, 21, 22, 23, 24, 25]
    dice_inputs, dice_input_sizes, dice_fuels = pcfg_inputs_from_approximate_sizes(dice_approximate_sizes)
    pcfg_dice_inputs[:inputs] = dice_inputs
    pcfg_dice_inputs[:input_sizes] = dice_input_sizes
    pcfg_dice_inputs[:fuels] = dice_fuels
    return pcfg_dice_inputs
end

# too big to prepopulate
pcfg_ours_inputs = Dict{Symbol, Any}()

function get_ours_inputs_pcfg()
    !isempty(pcfg_ours_inputs) && return pcfg_ours_inputs
    approximate_sizes = [10:10:100..., 200:50:650...]
    inputs, input_sizes, fuels = pcfg_inputs_from_approximate_sizes(approximate_sizes)
    pcfg_ours_inputs[:inputs] = inputs
    pcfg_ours_inputs[:input_sizes] = input_sizes
    pcfg_ours_inputs[:fuels] = fuels
    return pcfg_ours_inputs
end



