
@inductive Nonterminal SS() XX() YY()
@inductive Terminal aa() bb() cc()

function prob_list_append(l1::Dice.List{Terminal}, l2::Dice.List{Terminal}, fuel::Int)
    fuel == 0 && return Dice.Nil(Terminal)
    match(l1, [:Nil => () -> l2, :Cons => (hd, tl) -> Dice.Cons(Terminal, hd, prob_list_append(tl, l2, fuel-1))])
end


function generate_from_grammar(sym::Union{Dist{Nonterminal}, Nonterminal}, fuel::Int, append_fuel::Int)
    fuel == 0 && return Dice.Nil(Terminal)

    match(sym, [:XX => () -> (@dice_ite if flip(0.5); Dice.Cons(Terminal, bb(), prob_list_append(generate_from_grammar(XX(), fuel-1, append_fuel), generate_from_grammar(XX(), fuel-1, append_fuel), append_fuel)); else; Dice.Cons(Terminal, aa(), Dice.Nil(Terminal)); end),
                :YY => () -> (@dice_ite if flip(0.5); Dice.Cons(Terminal, cc(), generate_from_grammar(XX(), fuel-1, append_fuel)); else; (@dice_ite if flip(0.5); Dice.Cons(Terminal, cc(), generate_from_grammar(SS(), fuel-1, append_fuel)); else; Dice.Cons(Terminal, cc(), Dice.Nil(Terminal)); end); end),
                :SS => () -> (@dice_ite if flip(0.5); prob_list_append(generate_from_grammar(XX(), fuel-1, append_fuel), generate_from_grammar(YY(), fuel-1, append_fuel), append_fuel); else; prob_list_append(generate_from_grammar(YY(), fuel-1, append_fuel), generate_from_grammar(XX(), fuel-1, append_fuel), append_fuel); end)])

end

function pcfg_equals(l1::Dice.List{Terminal}, l2::Dice.List{Terminal}, fuel::Int)
    fuel == 0 && return false
    match(l1, [:Nil => () -> match(l2, [:Nil => () -> true, :Cons => (hd, tl) -> false]), :Cons => (hd1, tl1) -> match(l2, [:Nil => () -> false, :Cons => (hd2, tl2) -> (@dice_ite if prob_equals(hd1, hd2); pcfg_equals(tl1, tl2, fuel-1); else; false; end)])])
end

SYMBOL_TO_TERM = Dict(:a => aa(), :b => bb(), :c => cc())
function observation_list_from_symbols(symbols)
    if symbols == []
        return Dice.Nil(Terminal)
    else
        return Dice.Cons(Terminal, SYMBOL_TO_TERM[symbols[1]], observation_list_from_symbols(symbols[2:end]))
    end
end

function generate_observation_list(julia_list)
    obs_list = Dice.Nil(Terminal)
    sym_to_term = Dict(:aa => aa(), :bb => bb(), :cc => cc())
    for symbol in reverse(julia_list)
        obs_list = Dice.Cons(Terminal, sym_to_term[symbol], obs_list)
    end
    return obs_list
end


function pcfg_example(example, fuel, append_fuel)
    start = SS()
    return pr(pcfg_equals(generate_from_grammar(start, fuel, append_fuel), generate_observation_list(example), append_fuel))
end

len_23_fuel_11_example = [:cc, :bb, :bb, :bb, :aa, :bb, :bb, :aa, :bb, :aa, :bb, :bb, :aa, :bb, :aa, :aa, :aa, :aa, :aa, :bb, :aa, :aa, :aa]

add_benchmark!("pcfg", "dice_default", DiceBenchmark(() -> pcfg_example(len_23_fuel_11_example, 12, 24)))