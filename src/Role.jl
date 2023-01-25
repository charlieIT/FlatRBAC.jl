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
grant!(role, permissions::Permission...)
grant!(role, roles::Role...)
```

# Removing permissions and roles
```julia
revoke!(role, permissions::Permission...)

revoke!(role, roles::Role...)
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

name(role::Role)::String = Base.getfield(role, :name)
description(role::Role)::String = Base.getfield(role, :description)
permissions(role::Role)::Vector{<:AbstractPermission} = Base.getfield(role, :permissions)

grants(role::AbstractRole)::Grants = vcat(grants.(permissions(role))...)
Base.isempty(role::AbstractRole)::Bool = isempty(permissions(role))

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
    [Base.push!(base, permission) for permission in permissions(role) if !isequal(base, role)]
    return permissions(base)
end

function extend!(base::Role, roles::AbstractRole...)
    [extend!(base, role) for role in filter(x->!isequal(base, x), collect(roles))]
    return permissions(base)
end

function remove!(role::Role, permission::AbstractPermission; wildcards::Bool=true)
    return deleteat!(role.permissions, findall(x->implies(x, permission), permissions(role)))
end

"""Revoke `permission` from `role`"""
function revoke!(base::Role, permission::AbstractPermission; wildcards::Bool=true)
    remove!(base, permission, wildcards=wildcards)
end

"""Revoke set of `permissions` from `role`"""
function revoke!(base::Role, perms::AbstractPermission...; wildcards::Bool=true) 
    [revoke!(base, x, wildcards=wildcards) for x in perms]
end

"""Revoke from `base` all permissions from `role`"""
function revoke!(base::Role, role::AbstractRole; wildcards::Bool=true)
    [revoke!(base, permission, wildcards=wildcards) for permission in permissions(role)]
    return;
end

function Base.vect(roles::R...) where R<:AbstractRole
    return Vector{R}([r for r in unique(roles)])
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
function Base.getindex(vr::Vector{<:AbstractRole}, role_name::String)
    return vr[findall(r->name(r) == role_name, vr)]
end

function DataFrames.DataFrame(role::Role; kwargs...)
    permission_df = DataFrame(permissions(role); kwargs...)
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