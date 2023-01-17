
const WILDCARD_TOKEN = "*"

abstract type AbstractGrant end

mutable struct Grant <:AbstractGrant
    resource::String
    action::String

    function Grant()
        return new(WILDCARD_TOKEN, WILDCARD_TOKEN)
    end
    function Grant(res::AbstractString, act::AbstractString)
        return new(res, act)
    end
end
const Grants = Vector{<:AbstractGrant}

action(grant::Grant)::String   = Base.getfield(grant, :action)
resource(grant::Grant)::String = Base.getfield(grant, :resource)
iswildcard(grant::Grant)::Bool = iswildcard(action(grant)) && iswildcard(resource(grant))

Base.string(grant::Grant)::String = @sprintf "(%s:%s)" resource(grant) action(grant)
Base.show(io::IO, grant::Grant)   = print(io, string(grant))

function grants(res::Vector{<:AbstractString}, acts::Vector{<:AbstractString})::Grants
    return [Grant(string(x), string(y)) for x in res for y in acts]
end

function Base.Tuple(grant::AbstractGrant)::Tuple{String, String}
    return (resource(grant), action(grant),)
end

function Base.hash(grant::AbstractGrant)::UInt64
    return Base.hash(action(grant)) + Base.hash(resource(grant))
end

function Base.isequal(a::AbstractGrant, b::AbstractGrant)::Bool
    return hash(a) == hash(b)
end

function Base.vect(grants::G...) where G<:AbstractGrant
    return Vector{G}([g for g in unique(grants)])
end

function DataFrames.DataFrame(grant::AbstractGrant; kwargs...)::DataFrame
    return DataFrame(
        resource    = resource(grant),
        action      = action(grant),
        grant       = Tuple(grant);
        kwargs...
    )
end
function DataFrames.DataFrame(grants::Grants; kwargs...)::DataFrame
    return vcat(DataFrames.DataFrame.(grants; kwargs...)...)
end

function implies(this::AbstractGrant, that::AbstractGrant; scoped::Bool=true, kwargs...)
    return implies(action(this), action(that)) && implies(resource(this), resource(that))
end