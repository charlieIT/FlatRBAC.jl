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

const WILDCARD_TOKEN = "*"
const ALL_PERMISSIONS = ANY_RESOURCE = ANY_ACTION = ["*"]
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
    resources::Vector{String}
    actions::Vector{String}  
    description::String 
    scope::Type{<:Scope}      

    function Permission(name::String, resources::Vector{String}, actions::Vector{String}, description::String, scope::Type{<:Scope})
        resources = unique(string.(strip.(resources)))
        actions   = unique(string.(strip.(actions)))

        return new(string(strip(name)), resources, actions, description, scope)
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

"""
    Permission(str::String)

Build a Permission from a shorthand representation

# Examples
```julia
Permission("client:books:read,rent")
# Permission("client", ["books"], ["read", "rent"], "", None)

Permission("client::read,rent") # any resource
# Permission("client", ["*"], ["read", "rent"], "", None)

Permission("admin") # any resource, any actions
# Permission("admin", ["*"], ["*"], "", None)

Permission("staff:books") # any action over books
# Permission("staff", ["books"], ["*"], "", None)

Permission("multi-rental:books,cds:rent")
# Permission("multi-rental", ["books", "cds"], ["rent"], "", None)

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

    if !isempty(name)
        tmp.name = name
    end
    if isempty(parts)
        return Permission(name = tmp.name, description = tmp.description)
    end
    resources = filter(x->!isempty(x), split(first(parts), SUBPART_DIVIDER_TOKEN))
    if !isempty(resources)
        tmp.resources = string.(resources) # validated later at default constructor
    end
    if length(parts) > 1
        actions = filter(x->!isempty(x), split(parts[2], SUBPART_DIVIDER_TOKEN))
        if !isempty(actions)
            tmp.actions = string.(actions) # validated later at default constructor
        end
    end
    if length(parts) > 2 && !isempty(parts[3])
        tmp.scope = Scope(string(parts[3]))
    end
    return Permission(
        name        = tmp.name,
        description = tmp.description,
        resources   = tmp.resources,
        actions     = tmp.actions,
        scope       = tmp.scope
    )
end

macro perm(str)
    p = string(str)
    return :(Permission($p))
end

name(permission::Permission)        = permission.name
scope(permission::Permission)       = permission.scope
actions(permission::Permission)     = permission.actions
resources(permission::Permission)   = permission.resources
description(permission::Permission) = permission.description

function Base.vect(permissions::P...) where P<:AbstractPermission
    #@assert length(unique(permissions)) == length(permissions) "Non-unique permissions in set"
    return Vector{P}([p for p in unique(permissions)])
end

function Base.string(p::Permission)
    return @sprintf "%s:%s:%s:%s" name(p) join(resources(p), ",") join(actions(p), ",") lowercase(string(scope(p))) # name:operation:object, e.g., printer:print,query:inkjet
end

function Base.hash(permission::AbstractPermission)
    return Base.hash(name(permission)) + 
           Base.hash(sort(resources(permission))) +
           Base.hash(sort(actions(permission))) +
           Base.hash(scope(permission))
end

iswildcard(permission::AbstractPermission) = any(x->iswildcard(x), resources(permission)) && any(x->iswildcard(x), actions(permission))

function Base.isequal(a::P, b::P; kwargs...) where P<:AbstractPermission
    return sort(actions(a))   == sort(actions(b))   &&
           sort(resources(a)) == sort(resources(b)) &&
           scope(a) == scope(b)
end
Base.:(==)(a::P, b::P) where P<:AbstractPermission = Base.isequal(a, b)

function Base.in(perm::AbstractPermission, perms::Vector{<:AbstractPermission})
    return any(x->Base.isequal(x, perm), perms)
end

"""
    unwind(permission::P; flatten::Bool=false)

Deconstruct permission based on permission resources. If `flatten == true`, deconstruct also based on actions

Returns a set of permissions as Vector{Permission}

# Examples
```bash
julia> FlatRBAC.unwind(Permission("user_read:api,db:read,list"))

2-element Vector{Permission}:
 Permission("user_read", ["api"], ["read", "list"], "", FlatRBAC.None)
 Permission("user_read", ["db"], ["read", "list"], "", FlatRBAC.None)
```
```bash
julia> FlatRBAC.unwind(Permission("user_read:api,db:read,list"), flatten=true)

4-element Vector{Permission}:
 Permission("user_read", ["api"], ["read"], "", FlatRBAC.None)
 Permission("user_read", ["api"], ["list"], "", FlatRBAC.None)
 Permission("user_read", ["db"],  ["read"], "", FlatRBAC.None)
 Permission("user_read", ["db"],  ["list"], "", FlatRBAC.None)
```
"""
function unwind(permission::P; flatten::Bool=false)::Vector{Permission} where P<:AbstractPermission
    out = Permission[]
    if !flatten
        unwind_data = @inbounds [(x, actions(permission)...) for x in resources(permission)]
    else
        unwind_data = @inbounds [(x, y) for x in resources(permission) for y in actions(permission)]
    end
    @inbounds for (resource, actions...) in unwind_data
        push!(out, Permission(
                name      = name(permission), 
                resources = [resource], 
                actions   = collect(actions), 
                scope     = scope(permission))
        )
    end
    return out
end

function unwind(perms::Vector{P}; kwargs...)::Vector{Permission} where P<:AbstractPermission
    return Vector{Permission}([p for p in vcat(unwind.(perms; kwargs...)...)])
end

function DataFrames.DataFrame(permission::Permission; flatten::Bool=false, pretty::Bool=true, kwargs...)
    if flatten 
        return DataFrame(FlatRBAC.unwind(permission, flatten=true); pretty=pretty, kwargs...)
    end
    res = resources(permission)
    act = actions(permission)
    if pretty
        res = join(res, ", ")
        act = join(act, ", ")
    end
    return DataFrame(
        name        = name(permission),
        resources   = [res],
        actions     = [act],
        description = description(permission),
        scope       = scope(permission),
        shorthand   = Base.string(permission);
        kwargs...)
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
function implies(this::A, that::P; scoped::Bool=false, kwargs...) where {A<:AbstractPermission, P<:AbstractPermission}
    check = implies(resources(this), resources(that)) && implies(actions(this), actions(that))
    if scoped && check
        return implies(scope(this), scope(that))
    end
    return check
end
function implies(perms::Vector{<:AbstractPermission}, requirement::AbstractPermission; kwargs...)
    if isempty(perms)
        return false
    end
    requirements = unwind(requirement, flatten=true)
    coverage     = vcat(unwind.(perms, flatten=true)...)
    
    if isempty(coverage)
        return false
    end
    return implies(DataFrame(coverage), DataFrame(requirements); kwargs...)
end

"""
    _isauthorised(row::DataFrameRow, permission::DataFrameRow)::Bool

Check whether `row` authorised `permission`

Use only with flattened permissions (unwind at both resource and action level)
"""
function _isauthorised(row::DataFrameRow, permission::DataFrameRow; scoped::Bool=false, kwargs...)::Bool
    check::Bool = implies(row.resources, permission.resources) && implies(row.actions, permission.actions)
    if scoped && check
        return implies(row.scope, permission.scope)
    end   
    return check
end

"""Use only with flattened permissions"""
function implies(coverage::DataFrame, requirements::DataFrame; scoped::Bool=false, audit::Bool=false, kwargs...)
    function force_flatten(df::DataFrame)
        for col in [:resources, :actions]
            if !(eltype(df[!, col]) <:String)
                df = flatten(df, col)
            end
        end
        return df
    end
    requirements = force_flatten(requirements)
    coverage     = force_flatten(coverage)
    check::DataFrame = deepcopy(requirements[!, [:resources, :actions, :scope]])

    for (i, row) in enumerate(eachrow(requirements))
        if any(x->_isauthorised(x, row; scoped=scoped, kwargs...), eachrow(coverage))
            deleteat!(check, 1)
        end
    end
    if audit
        remaining = filter(row->row.resources in check.resources && row.actions in check.actions, requirements)
        println(remaining)
    end
    return isempty(check)
end

function Base.filter(perms::Vector{P}, requirement::AbstractPermission; scoped::Bool=false, kwargs...) where P<:AbstractPermission
    return Vector{P}([p for p in Base.filter(p->implies(p, requirement, scoped=scoped, kwargs...), perms)])
end

#= //END TODO =#