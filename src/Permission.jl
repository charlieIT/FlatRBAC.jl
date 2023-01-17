"""
    type AbstractPermission

# Interface methods

 - name()::String
 - actions()::Vector{String}
 - resources()::Vector{String}
 - scope()::Scope
 - hash()::UInt64

# Implementing custom permissions

```julia
struct CustomPermission
    activity::String
    resources::Vector{Symbol}
end

FlatRBAC.name(custom::CustomPermission)      = Base.string(CustomPermission)
FlatRBAC.scope(custom::CustomPermission)     = FlatRBAC.All
FlatRBAC.actions(custom::CustomPermission)   = [custom.activity]
FlatRBAC.resources(custom::CustomPermission) = string.(custom.resources)
```
"""
abstract type AbstractPermission end

const ALL_PERMISSIONS = ANY_RESOURCE = ANY_ACTION = [WILDCARD_TOKEN]
const DIVIDER_TOKEN = ":"
const SUBPART_DIVIDER_TOKEN = ","
iswildcard(str::String) = str == WILDCARD_TOKEN

"""
    mutable struct Permissions <:AbstractPermission

Permissions dot not know `who` can perform actions, only what can be performed on resources

# Examples
```julia
rent_book = Permission("books", ["ulysses"], ["read", "rent"])
// alternatively
rent_book = Permission("ulysses:read,rent")
```
"""
mutable struct Permission <:AbstractPermission
    name::String
    grants::Grants  
    description::String 
    scope::Type{<:Scope}      

    
    function Permission(name::String, grants::Grants, description::String, scope::Type{<:Scope})
        return new(string(strip(name)), grants, description, scope)
    end
    function Permission(name::String, resources::Vector{String}, actions::Vector{String}, description::String, scope::Type{<:Scope})
        resources = unique(string.(strip.(resources)))
        actions   = unique(string.(strip.(actions)))

        return Permission(name, grants(resources, actions), description, scope)
    end

    function Permission(;
        name::String              = "",
        resources::Vector{String} = ANY_RESOURCE,
        actions::Vector{String}   = ALL_PERMISSIONS,
        description::String       = "",
        scope::Type{<:Scope}      = None)
        
        return Permission(name, resources, actions, description, scope)
    end
end

name(permission::Permission)             = Base.getfield(permission, :name)
scope(permission::Permission)            = Base.getfield(permission, :scope)
grants(permission::Permission)           = Base.getfield(permission, :grants)
actions(permission::Permission)          = action.(grants(permission))
resources(permission::Permission)        = resource.(grants(permission))
description(permission::Permission)      = Base.getfield(permission, :description)
grants(vp::Vector{<:AbstractPermission}) = vcat(grants.(vp)...)

"""
    Permission(str::String)

Build a Permission from a shorthand representation

# Examples
```julia
Permission("client:books:read,rent")
# client:(books:read)(books:rent):none

Permission("client::read,rent") # any resource
# Permission("client", ["*"], ["read", "rent"], "", None)

Permission("admin") # any resource, any actions
# Permission("admin", ["*"], ["*"], "", None)

Permission("staff:books") # any action over books
# Permission("staff", ["books"], ["*"], "", None)

Permission("multi-rental:books,cds:rent")
# multi-rental:(books:rent)(cds:rent):none

Permission("author:*:update:own", "An author can update their own resources")
# Permission("author", ["*"], ["update"], "An author can update their own resources", Own)
```
"""
function Permission(str::String, description::String="")::Permission
    if  isempty(str) ||
        str == DIVIDER_TOKEN ||
        all(x->string(x) in [DIVIDER_TOKEN, SUBPART_DIVIDER_TOKEN], str)

        throw(InvalidPermissionExpression(str))
    end

    tmp = Permission(description=description) # acquire default values
    name, parts... = split(str, DIVIDER_TOKEN)

    res  = ANY_RESOURCE
    acts = ANY_ACTION

    if !isempty(name)
        tmp.name = name
    end
    if isempty(parts)
        return Permission(name = tmp.name, description = tmp.description)
    end
    resources = filter(x->!isempty(x), split(first(parts), SUBPART_DIVIDER_TOKEN))
    if !isempty(resources)
        res = string.(resources) # validated later at default constructor
    end
    if length(parts) > 1
        actions = filter(x->!isempty(x), split(parts[2], SUBPART_DIVIDER_TOKEN))
        if !isempty(actions)
            acts = string.(actions) # validated later at default constructor
        end
    end
    if length(parts) > 2 && !isempty(parts[3])
        tmp.scope = Scope(string(parts[3]))
    end
    return Permission(
        name        = tmp.name,
        description = tmp.description,
        resources   = res,
        actions     = acts,
        scope       = tmp.scope
    )
end

function Base.string(p::Permission)
    return @sprintf "%s:%s:%s:%s" name(p) join(unique(resources(p)), ",") join(unique(actions(p)), ",") lowercase(string(scope(p))) # name:operation:object, e.g., printer:print,query:inkjet
end
function Base.show(io::IO, p::Permission)
    #displ = @sprintf "%s:%s:%s" name(p) join(string.(grants(p)), "") lowercase(string(scope(p)))
    print(io, string(p))
end

function Base.vect(permissions::P...) where P<:AbstractPermission
    return Vector{P}([p for p in unique(permissions)])
end

function Base.hash(permission::AbstractPermission)
    return Base.hash(name(permission)) + 
           Base.hash(sort(resources(permission))) +
           Base.hash(sort(actions(permission))) +
           Base.hash(scope(permission))
end

function iswildcard(permission::AbstractPermission; scoped::Bool=false)::Bool
    check = any(x->iswildcard(x), resources(permission)) && any(x->iswildcard(x), actions(permission))
    if check && scoped
        return iswildcard(scope(permission))
    end
    return check
end

function Base.isequal(a::P, b::P; kwargs...) where P<:AbstractPermission
    return sort(actions(a))   == sort(actions(b))   &&
           sort(resources(a)) == sort(resources(b)) &&
           scope(a) == scope(b)
end
Base.:(==)(a::P, b::P) where P<:AbstractPermission = Base.isequal(a, b)

function Base.in(perm::AbstractPermission, perms::Vector{<:AbstractPermission})
    return any(x->Base.isequal(x, perm), perms)
end

function DataFrames.DataFrame(permission::Permission; kwargs...)

    out = crossjoin(
        DataFrame(
            name        = name(permission),
            description = description(permission),
            scope       = scope(permission),
            shorthand   = Base.string(permission);
            kwargs...),
        DataFrame(grants(permission));
        kwargs...
    )
    return select(out, :name, :resource, :action, :scope, :description, :shorthand)
end

function DataFrames.DataFrame(permissions::Vector{Permission}; kwargs...)
    return vcat(DataFrames.DataFrame.(permissions; kwargs...)...)
end

function implies(this::String, that::String; kwargs...)
    return iswildcard(this) || this == that
end

function implies(this::Vector{String}, that::Vector{String}; kwargs...)
    if any(x->iswildcard(x), this)
        return true
    end
    return setdiff(that, this) |> isempty
end

"""
    implies(this::P, that::P) where P<:AbstractPermission

Check whether a permission implies another permission is granted

`this` must satisfy all [`resource`=>`actions`...] combinations from `that`

# Example
```
# A permission to grant an user access to read and list its own data
user_perm = Permission("user_read:database:read,list:own")

implies(user_perm, Permission(":database:read:own")) == true # user can both read and list

implies(user_perm, Permission(":database:read,list,delete:own")) == false # user cannot delete
implies(user_perm, Permission(":database:read:all"), scoped=true) == false # user cannot read in all scope
```
"""
function implies(this::A, that::P; scoped::Bool=true, kwargs...) where {A<:AbstractPermission, P<:AbstractPermission}
    if scoped && iswildcard(this, scoped=scoped)
        return true
    end

    check = implies(resources(this), resources(that)) && implies(actions(this), actions(that))
    if scoped && check
        return implies(scope(this), scope(that))
    end
    return check
end

function implies(perms::Vector{<:AbstractPermission}, requirement::AbstractPermission; scoped::Bool=true, kwargs...)
    if isempty(perms)
        return false
    end
    if scoped && any(x->iswildcard(x, scoped=scoped), perms)
        return true
    end
    perms = filter(x->!isempty(grants(x)), perms)

    requirements::Grants = deepcopy(grants(requirement))
    coverage = @inbounds [(g, scope(p)) for p in perms for g in grants(p)]
    
    @time for grant in grants(requirement)
        match = findfirst(x->implies(first(x), grant), coverage)
        check::Bool = !isnothing(match)
        if check && scoped
            check = implies(last(coverage[match]), scope(requirement))
        end
        if check
            deleteat!(requirements, findall(x->hash(match) == hash(x), requirements))
        end
    end

    #@time implies(DataFrame(perms), DataFrame(requirement); kwargs...)
    return isempty(requirements)
end

function Base.filter(perms::Vector{P}, requirement::AbstractPermission; scoped::Bool=true, kwargs...) where P<:AbstractPermission
    return Vector{P}([p for p in Base.filter(p->implies(p, requirement, scoped=scoped, kwargs...), perms)])
end

# """
#     _isauthorised(row::DataFrameRow, permission::DataFrameRow)::Bool

# Check whether `row` authorised `permission`

# Use only with flattened permissions (unwind at both resource and action level)
# """
# function _isauthorised(row::DataFrameRow, permission::DataFrameRow; scoped::Bool=true, kwargs...)::Bool
#     check::Bool = implies(row.resource, permission.resource) && implies(row.action, permission.action)
#     if scoped && check
#         return implies(row.scope, permission.scope)
#     end   
#     return check
# end

# """Use only with flattened permissions"""
# function implies(coverage::DataFrame, requirements::DataFrame; scoped::Bool=true, audit::Bool=false, kwargs...)
#     check::DataFrame = deepcopy(requirements[!, [:resource, :action, :scope]])

#     for (i, row) in enumerate(eachrow(requirements))
#         if any(x->_isauthorised(x, row; scoped=scoped, kwargs...), eachrow(coverage))
#             deleteat!(check, 1)
#         end
#     end
#     if audit
#         remaining = filter(row->row.resources in check.resources && row.actions in check.actions, requirements)
#         println(remaining)
#     end
#     return isempty(check)
# end

#= //END TODO =#