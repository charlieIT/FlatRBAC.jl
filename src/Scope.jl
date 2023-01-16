"""
    type Scope

# Interface methods

 - Base.string(scope::Scope)::String
 - iswildcard(scope::Scope)::Bool
 - Scope(::Val{:lowercaseName})::Scope
"""
abstract type Scope end

abstract type None   <:Scope end
abstract type All    <:Scope end
abstract type Own    <:Scope end

Base.string(::Type{All}) = "all"
Base.string(::Type{Own}) = "own"
Base.string(::Type{Any}) = "any"

Scope(::Val{:all})  = All
Scope(::Val{:none}) = None
Scope(::Val{:own})  = Own

iswildcard(::Type{<:Scope}) = false
iswildcard(::Type{All})     = true

"""
    function Scope(str::String)

Construct Scope from a string representation

# Examples
```julia
abstract type MyScope <:FlatRBAC.Scope end

Base.string(::Type{MyScope})    = "MyScope"

# Implementing this interface significantly improves performance
FlatRBAC.Scope(::Val{:myscope}) = MyScope

# Case insensitive, will check against lowercase representation
@assert FlatRBAC.Scope("MySCOPE") == MyScope "This should not error"
```
"""
function Scope(str::String)
    return Scope(Symbol(lowercase(str)))
end
function Scope(s::Symbol)
    if hasmethod(Scope, (Val{s}, ))
        return Scope(Val(s))
    end
    return _scope_from_str(string(s)) # from utils.jl
end

# Generic string implementation for any Scope subtype
function Base.string(::Type{S}) where S<:Scope
    io = IOBuffer();
    print(io, S)
    s = String(take!(io))
    return last(string.(split(s, ".")))
end

#= implies =#

"""Default Scope cases"""
function implies(this::Type{S}, that::Type{P}; kwargs...) where {S<:Scope, P<:Scope}
    return  iswildcard(this) || # Check for wildcard custom implementation, wildcard should grant anything
            this == All      || # Default wildcard Scope (All) grants any scope
            that <: None     || # Check against None permissions is always true
            that <: this        # supertypes grant subtypes
end

"""Checking against Own defaults to true, devs are responsible for appropriate ownership checks"""
function implies(this::Type{S}, that::Type{O}; kwargs...) where {S<:Scope, O<:Own}
    if this <: Own
        return that <: this # supertypes grant subtypes
    end
    return true
end

"""Checking same scope is always true"""
implies(this::Type{S}, that::Type{S}; kwargs...) where S<:Scope = true
"""Checking Own supertype against Own subtypes is always true, devs are responsible for appropriate ownership checks"""
implies(this::Type{Own}, that::Type{O}; kwargs...) where O<:Own = true
"""None does not grant Own"""
implies(this::Type{N}, that::Type{O}; kwargs...) where {N<:None, O<:Own}  = false