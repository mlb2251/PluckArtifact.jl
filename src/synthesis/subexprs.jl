export SubExpr,
    subexpr,
    subexpr!,
    undo_subexpr!,
    subexpr_inner!,
    descendants_untyped

"""
Information about a subexpression of another expression
"""
mutable struct SubExpr
    child::PExpr
    type::PType # of child
    env::Vector{PType} # of child
    env_names::Vector{Symbol} # of child
    path::Vector{Int} # to child
end

Base.copy(se::SubExpr) =
    SubExpr(se.child, se.type, copy(se.env), copy(se.env_names), copy(se.path))
SubExpr(e::PExpr, t::PType, env, env_names) = SubExpr(e, t, env, env_names, Int[])
SubExpr(e::String, t::String, env, env_names) = SubExpr(parse_expr(e), parse_type(t), env, env_names)

"""
modifies `se` in place to be the `i`th child of `se`.
Note that if `se` is an Abs, it will descend through all
the whole chain of Abs.
"""

function subexpr_inner!(e::PExpr{Abs}, se::SubExpr, i::Int)
    insert!(se.env, 1, arg_types(se.type)[1])
    insert!(se.env_names, 1, se.child.head.var)
    se.type = getchildtype(se.child, i, se.type, se.env)
    se.child = getchild(se.child, i)
    se
end

function subexpr_inner!(e::PExpr{Construct}, se::SubExpr, i::Int)
    se.type = getchildtype(se.child, i, se.type, se.env)
    se.child = getchild(se.child, i)
    se
end

function subexpr_inner!(e::PExpr{CaseOf}, se::SubExpr, i::Int)
    se.type = getchildtype(se.child, i, se.type, se.env)
    se.child = getchild(se.child, i)
    # note that we don't descend pass the lambdas of the branches
    # just as we don't descend past the lambda of higher order args
    se
end

function subexpr_inner!(e::PExpr{App}, se::SubExpr, i::Int)
    se.type = getchildtype(se.child, i, se.type, se.env)
    se.child = getchild(se.child, i)
    se
end

function subexpr!(se::SubExpr, i::Int)
    backtrack = (se.child, se.type, length(se.env))
    subexpr_inner!(se.child, se, i) # "e" is just for dispatch ugh
    push!(se.path, i)
    backtrack
end

function subexpr!(se::SubExpr, path::Vector{Int})
    @assert length(se.env) == length(se.env_names)
    backtrack = (se.child, se.type, length(se.env))
    for i in path
        subexpr!(se, i)
    end
    backtrack
end

function undo_subexpr!(se::SubExpr, backtrack)
    se.child, se.type, env_len = backtrack
    while env_len < length(se.env)
        deleteat!(se.env, 1)
        deleteat!(se.env_names, 1)
    end
    pop!(se.path)
    se
end


mutable struct UntypedIterDescendants{F}
    e::PExpr
    path::Vector{Int}
    allow_descend::F
end

Base.IteratorSize(::Type{UntypedIterDescendants}) = Base.SizeUnknown()

"""
like `descendants_inplace` but for untyped expressions
"""
descendants_untyped(e::PExpr, path::Vector{Int} = Int[], allow_descend = x -> true) =
    Iterators.flatten((((e,path),), UntypedIterDescendants(copy(e), copy(path), allow_descend)))

mutable struct UntypedIterState
    e::PExpr
    path::Vector{Int}
    stack::Vector{PExpr}
end

function Base.iterate(
    iter::UntypedIterDescendants{F},
    state = UntypedIterState(iter.e, iter.path, PExpr[]),
) where {F}
    # invariant: each time iterate it called, the last thing we yielded
    # was (state.e, state.path). That means the next thing to do is yield any children it has

    i = 1
    while !haschild(state.e, i) || !iter.allow_descend(state.e)
        isempty(state.stack) && return nothing
        # state.e has no children! Lets backtrack, setting both state.e and state.path
        # to those of our parent, and setting `i` to our next sibling
        state.e = pop!(state.stack)
        i = pop!(state.path) + 1
    end
    # we have a child to yield
    push!(state.path, i)
    push!(state.stack, state.e)
    state.e = getchild(state.e, i)
    return ((state.e, copy(state.path)), state)
end


Base.show(io::IO, se::SubExpr) =
    print(io, "SubExpr(", se.child, "::", se.type, " @ ", se.path, " w ", se.env, ")")



function cfg_symbol_paths(e::PExpr)
    res = []
    for (e, path) in descendants_untyped(e)
        if e isa PExpr{GSymbol} || e isa PExpr{GVarSymbol}
            push!(res, (e, path))
        end
    end
    res
end

function setchild!(e::PExpr{App}, i::Int, child)
    apps = num_children(e) - 1
    # i > apps + 1 && error("Trying to access child $i of an App that has $(args+1) children (including the function itself)")
    # silly temp hard coding
    @assert apps > 0
    if apps == 1
        if i == 1
            e.args[1] = child
        elseif i == 2
            e.args[2] = child
        else
            error("unreachable")
        end
    elseif apps == 2
        if i == 1
            e.args[1].args[1] = child
        elseif i == 2
            e.args[1].args[2] = child
        elseif i == 3
            e.args[2] = child
        else
            error("unreachable")
        end
    elseif apps == 3
        if i == 1
            e.args[1].args[1].args[1] = child
        elseif i == 2
            e.args[1].args[1].args[2] = child
        elseif i == 3
            e.args[1].args[2] = child
        elseif i == 4
            e.args[2] = child
        else
            error("unreachable")
        end
    else
        error("too many apps")
    end
end


function getchild(e::PExpr{App}, i::Int)
    if i == 1
        Pluck.getfunc(e)
    else
        Pluck.getarg(e, i - 1)
    end
end


num_children(e::PExpr{App}) = 1 + Pluck.num_apps(e)

num_children(e::PExpr) = length(e.args)
setchild!(e::PExpr, i::Int, child) = (e.args[i] = child)
function getchild(e::PExpr, i::Int)
    # println("e: $e i: $i")
    return e.args[i]
end


function getchildtype(e, path::Vector{Int}, t, env)
    for i in path
        t = getchildtype(e, i, t, env)
        e = getchild(e, i)
    end
    t
end

function getchild(e, path::Vector{Int})
    for i in path
        e = getchild(e, i)
    end
    e
end

function haschild(e, path::Vector{Int})
    for i in path
        if num_children(e) < i
            return false
        end
        e = getchild(e, i)
    end
    return true
end

function haschild(e, i::Int)
    num_children(e) >= i
end

function setchild!(e, path::Vector{Int}, child)
    @assert !isempty(path)
    for i ∈ 1:length(path)-1
        e = getchild(e, path[i])
    end
    setchild!(e, path[end], child)
end

function unifies(e1::PExpr, e2::PExpr)
    # CFG symbols unify with anything
    (e1 isa PExpr{GSymbol} || e1 isa PExpr{GVarSymbol} || e2 isa PExpr{GSymbol} || e2 isa PExpr{GVarSymbol}) && return true
    # Head (and implicity type) must match
    e1.head == e2.head || return false
    # Children must match
    length(e1.args) == length(e2.args) || return false
    all(unifies(a, b) for (a, b) in zip(e1.args, e2.args))
end


function getchildtype(e::PExpr{Construct}, i::Int, t, env)
    BaseType(type_of_constructor[args_of_constructor[e.constructor][i]])
end

function getchildtype(e::PExpr{CaseOf}, i::Int, t, env)
    # scrutinee - look it up based on the first constructor
    i == 1 && return BaseType(type_of_constructor[e.head.branches[1].constructor])
    # branches are lambdas from the constructor args to the return type
    # constructor = e.branches[i-1].constructor
    # arg_types = [type_of_constructor[args_of_constructor[constructor][j]] for j in 1:length(args_of_constructor[constructor])]
    # length(arg_types) == 0 && return t
    # return Arrow(arg_types, t)
    return t
end

function getchildtype(e::PExpr{App}, i::Int, t, env)
    f = Pluck.getfunc(e)
    ftype = get_func_type(f, env)
    i == 1 && return ftype
    return arg_types(ftype)[i-1]
end

function getchildtype(e::PExpr{Abs}, i::Int, t, env)
    num_args(t) == 1 && return return_type(t)
    Arrow(arg_types(t)[2:end], return_type(t))
end

function get_func_type(f::PExpr{Defined}, env)
    return DEF_TYPES[f.head.name]
end
get_func_type(f::PExpr{Pluck.Var}, env) = env[f.head.idx]

