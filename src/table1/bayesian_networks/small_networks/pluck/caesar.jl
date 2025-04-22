
# Reference code from Dice artifact
# fun sendChar(arg: (int(4), int(4))) {
#   let key = fst arg in
#   let observation = snd arg in
#   let gen = discrete(0.5, 0.25, 0.125, 0.125) in    // sample a FooLang character
#   let enc = key + gen in                            // encrypt the character
#   let tmp = observe observation == enc in
#   (key, observation)
# }
# // sample a uniform random key: A=0, B=1, C=2, D=3
# let key = discrete(0.25, 0.25, 0.25, 0.25) in
# // observe the ciphertext CCCC
# let tmp = iterate(sendChar, (key, int(4, 2)), 4) in
# key


function caesar_defs()
    CAESAR_CHAR_TYPE = Pluck.define_type!(:Char, Dict(Symbol("$(a)_") => Symbol[] for a = 'a':'d'))

    @define "random_key" """
    (if (flip 0.25)
        (a_)
        (if (flip 0.33333)
        (b_)
        (if (flip 0.5)
            (c_)
            (d_))))
    """
    @define "random_char" """
    (if (flip 0.5)
    (a_)
    (if (flip 0.5)
        (b_)
        (if (flip 0.5)
        (c_)
        (d_))))
    """

    @define "strings_eq" """
    (Y (λ strings_eq l1 l2 -> (case l1 of 
    Nil => (case l2 of Nil => true | Cons _ _ => false)
    Cons c1 c2 => (case l2 of Nil => false | Cons c3 c4 => (and (constructors_equal c1 c3) (strings_eq c2 c4)))
    )))
    """

    @define "char_to_num" "(lambda c -> (case c of a_ => 0 | b_ => 1 | c_ => 2 | d_ => 3))"

    @define "rotate_char" """
    (Y (λ rotate_char n c ->
        (case n of 
        O => c
        | S m => (rotate_char m (case c of
        a_ => (b_)
        b_ => (c_)
        c_ => (d_)
        d_ => (a_)
        )))
    ))
    """

    @define "encrypt_message" """
    (λ key message -> (map (λ c -> (rotate_char key c)) message))
    """

    @define "random_string" """
    (Y (λ random_string n ->
        (case n of O => (Nil) | S m => (Cons random_char (random_string m)))))
    """

    @define "caesar" """
    (λ observed -> (let 
        (key random_key
        msg (random_string (length observed))
        encrypted (encrypt_message (char_to_num key) msg))
        (given (strings_eq observed encrypted) key)))
    """
end

function julia_string_to_expression_caesar(s)
    e = ""
    for char in s
        e *= "(Cons ($(char)_) "
    end
    e *= "(Nil)" * repeat(")", length(s))
    return e
end

make_caesar_example(n) = "(caesar $(julia_string_to_expression_caesar(join("c" for _ in 1:n))))"

add_benchmark!("caesar", "pluck_default", PluckBenchmark(make_caesar_example(100); normalize=true, pre=caesar_defs))
add_benchmark!("caesar", "pluck_strict_enum", PluckBenchmark(make_caesar_example(100); normalize=true, pre=caesar_defs, timeout=true))