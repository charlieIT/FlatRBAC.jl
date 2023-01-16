"""
    type AbstractSubject

# Interface methods
 
 * id::String 
 * name::String
 * roles::Vector{<:AbstractRole}
 * hash()::UInt64
"""
abstract type AbstractSubject end

"""
    mutable struct Subject <:AbstractSubject

A subject represents and entity interacting with an application

In a flat RBAC model, subjects will obtain permissions from their assigned roles, direct assignment is not supported

# Methods

 * grant!
 * revoke!
"""
Base.@kwdef mutable struct Subject <:AbstractSubject
    id::String
    name::String                    = id
    roles::Vector{<:AbstractRole}   = AbstractRole[]
end

id(user::Subject) = user.id
roles(user::Subject) = user.roles
name(user::Subject) = user.name
function permissions(user::Subject; shorthand::Bool=false)
    return unique(vcat(permissions.(roles(user), shorthand=shorthand)...))
end

# //TODO Ignorar em caso de duplicado
function grant!(user::Subject, role::AbstractRole)
    user.roles = [roles(user)..., role] # invoke Base.vect defined over Role vectors and automatically check for duplicates
    return roles(user)
end

"""Revoke `role` from `subject`"""
function revoke!(user::Subject, role::AbstractRole)
    return deleteat!(user.roles, findall(x->Base.isequal(role, x), roles(user)))
end