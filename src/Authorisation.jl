function isauthorised(perms::Vector{P}, permission::AbstractPermission; scoped::Bool=true, kwargs...) ::Bool where P<:AbstractPermission
    if isempty(perms)
        return false
    end
    if permission in perms
        return true
    end
    return implies(perms, permission; scoped=scoped, kwargs...)
end
isauthorised(subject::AbstractPermission, permission::AbstractPermission; kwargs...) = implies(subject, permission; kwargs...)

function isauthorised(role::AbstractRole, permission::AbstractPermission; scoped::Bool=true, kwargs...)::Bool
    return !isempty(role) && isauthorised(permissions(role), permission; scoped=scoped, kwargs...)      
end

function isauthorised(roles::Vector{<:AbstractRole}, permission::AbstractPermission; singlerole::Bool=false, scoped::Bool=true, kwargs...)::Bool
    if isempty(roles)
        return false
    end
    if singlerole
        return any(role->isauthorised(role, permission; scoped=scoped, kwargs...), roles)
    end
    return isauthorised(vcat(permissions.(roles)...), permission; scoped=scoped, kwargs...)
end

function isauthorised(subject::AbstractSubject, permission::AbstractPermission; singlerole::Bool=false, scoped::Bool=true, kwargs...)::Bool
    return isauthorised(roles(subject), permission; singlerole=singlerole, scoped=scoped, kwargs...)
end

#= Dispatch for string based permissions =#
function isauthorised(subject::T, permission_str::String; kwargs...)::Bool where T<:Union{AbstractPermission, AbstractRole, AbstractSubject}
    return isauthorised(subject, Permission(permission_str); kwargs...)
end
function isauthorised(subject::V, permission_str::String; kwargs...)::Bool where V<:Union{Vector{<:AbstractPermission}, Vector{<:AbstractRole}, Vector{<:AbstractSubject}}
    return isauthorised(subject, Permission(permission_str); kwargs...) 
end

#= Experimental =#
Base.@kwdef struct Authorisation
    granted::Bool
    permission::AbstractPermission
    subject::Union{Nothing, AbstractSubject} = nothing
end

Base.:(==)(result::Authorisation, bool::Bool) = result.granted == bool
Base.:(!)(result::Authorisation) = !result.granted
function Base.show(io::IO, result::Authorisation)
    p_str::String = Base.string(result.permission)
    str = @sprintf "%s: %s \n%s: '%s'" :granted result.granted :permission p_str
    return print(io, str)
end

function authorise(f::Function, subject::AbstractSubject, perm::AbstractPermission, args...; kwargs...)
    return f(Authorisation(isauthorised(subject, perm; kwargs...), perm, subject))
end
function authorise(f::Function, subject::AbstractSubject, perm::String, args...; kwargs...)
    return authorise(f, subject, Permission(perm), args...; kwargs...)
end