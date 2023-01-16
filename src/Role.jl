"""
    type AbstractRole

Roles are collection of permissions and can be assigned to subjects

# Interface methods
 
 - `name(<:AbstractRole)::String`
 - `description(<:AbstractRole)::String`
 - `permissions(<:AbstractRole)::Vector{<:AbstractPermission}`
 - `hash(<:AbstractRole)::UInt64`
"""
abstract type AbstractRole end

"""
    mutable struct Role <:AbstractRole

# Grating permissions 
```julia
grant!(role, permission::Permission)
grant!(role, anotherRole::Role)
grant!(role, permission, role, ...)
```

# Removing permissions
```julia
revoke!(role, permission::Permission)

revoke!(role, permission, role, ...)
```
"""
mutable struct Role <:AbstractRole
    name::String
    description::String
    permissions::Vector{<:AbstractPermission}

    function Role(name::String, description::String, perms::Vector{<:AbstractPermission})
        return new(name, description, unique(perms))
    end
    function Role(; name::String, description::String="", permissions::Vector{<:AbstractPermission}=Permission[])
        return Role(name, description, permissions)
    end
    function Role(name::String, permissions::P...; description::String="") where P<:AbstractPermission
        return Role(name, description, Vector{P}([p for p in collect(permissions)]))
    end
end

name(role::Role)        = role.name
description(role::Role) = role.description
function permissions(role::Role; shorthand::Bool=false) 
    if shorthand
       return string.(role.permissions) 
    end
    return role.permissions
end
Base.isempty(role::AbstractRole) = isempty(permissions(role))

function Base.push!(role::Role, permission::P) where P<:AbstractPermission
    if !(permission in role)
        Base.push!(role.permissions, permission)
    end
    return permissions(role)
end
grant!(role::Role, permission::AbstractPermission) = Base.push!(role, permission)

function grant!(base::Role, grants::AbstractPermission...)
    [grant!(base, perm) for perm in grants]
    return base
end
function grant!(base::Role, roles::AbstractRole...)
    extend!(base, roles...)
    return base
end

function grant!(base::Role, grants::String...)
    grants = collect(grants)
    perms  = Permission.(grants) # convert str permission to permissions objects
    return grant!(base, perms...)
end

function extend!(base::Role, role::AbstractRole)
    [Base.push!(base, permission) for permission in permissions(role)]
    return permissions(base)
end

function extend!(base::Role, roles::AbstractRole...)
    [extend!(base, role) for role in collect(roles)]
    return permissions(base)
end

function remove!(role::Role, permission::AbstractPermission)
    return deleteat!(role.permissions, findall(x->x == permission, permissions(role)))
end

"""Revoke `permission` from `role`"""
revoke!(base::Role, permission::AbstractPermission) = remove!(base, permission)

"""Revoke set of `permissions` from `role`"""
revoke!(base::Role, perms::AbstractPermission...) = [revoke!(base, x) for x in perms]

"""Revoke from `base` all permissions from `role`"""
function revoke!(base::Role, role::AbstractRole)
    [revoke!(base, permission) for permission in permissions(role)]
    return;
end

function Base.vect(roles::R...) where R<:AbstractRole
    names::Vector{String} = name.(collect(roles))
    @assert length(unique(roles)) == length(roles) throw(ArgumentError("Non-unique roles in set"))
    return Vector{R}([r for r in roles])
end

function Base.hash(role::Role)
    return Base.hash(name(role)) + 
           Base.hash(sort([hash(p) for p in permissions(role)]))
end

function Base.isequal(a::R, b::R) where R<:AbstractRole
    return hash(a) == hash(b)
end
Base.:(==)(a::R, b::R) where R<:AbstractRole = Base.isequal(a, b)

function Base.in(role::R, roles::Vector{<:R}) where R<:AbstractRole
    return any(x->Base.isequal(role, x), roles)
end

function Base.in(permission::P, role::R) where {R<:AbstractRole, P<:AbstractPermission}
    return Base.in(permission, permissions(role))
end

function Base.getindex(role::Role, permission::AbstractPermission)
    return Base.getindex(role, name(permission))
end
function Base.getindex(role::Role, permission::String)
    return permissions(role)[findfirst(x->name(x) == permission, permissions(role))]
end

function DataFrames.DataFrame(role::Role; flatten::Bool=false, kwargs...)
    permission_df = DataFrame(permissions(role); flatten=flatten, kwargs...)
    rename!(permission_df, [:name=>:permission, :description=>:permission_desc])
    return crossjoin(
        DataFrame(name = name(role), description = description(role)),
        permission_df;
        kwargs...
    )
end

function DataFrames.DataFrame(roles::Vector{Role}; kwargs...)
    return vcat(DataFrames.DataFrame.(roles; kwargs...)...)
end