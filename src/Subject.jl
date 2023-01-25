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

id(user::Subject)    = Base.getfield(user, :id)
name(user::Subject)  = Base.getfield(user, :name)
roles(user::Subject) = Base.getfield(user, :roles)
function permissions(user::Subject)
    return unique(vcat(permissions.(roles(user))...))
end

# //TODO Ignorar em caso de duplicado
function grant!(user::Subject, rls::AbstractRole...)
    user.roles = [roles(user)..., collect(rls)...] # invoke Base.vect defined over Role vectors and automatically check for duplicates
    return roles(user)
end

"""Revoke `role` from `subject`"""
function revoke!(user::Subject, role::AbstractRole)
    return deleteat!(user.roles, findall(x->Base.isequal(role, x), roles(user)))
end