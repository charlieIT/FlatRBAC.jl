### Permission
-------------------------------

A `Permission` is a mechanism for authorisation, specifying `actions` a given `subject` can perform over system `resources`. 

Permissions may be defined in `shorthand` form as `<name>:<resources>:<actions>:<scope>`.
```bash
julia> cruds = Permission(name="admin", resources=["*"], actions=["create", "read", "update", "delete"], scope=FlatRBAC.All, description="CRUD Admin")
Permission("admin", ["*"], ["create", "read", "update", "delete"], "CRUD Admin", FlatRBAC.None)

julia> shorthand = Permission("admin:*:create,read,update,delete:all", "CRUD Admin")
Permission("admin", ["*"], ["create", "read", "update", "delete"], "CRUD Admin", FlatRBAC.None)
```

#### AbstractPermission - Type

A Permission is a subtype of `AbstractPermission`, which defines the following **interface methods**:
>- `name(<:AbstractPermission)::String`
>- `scope(<:AbstractPermission)::Scope`
>- `actions(<:AbstractPermission)::Vector{String}`
>- `resources(<:AbstractPermission)::Vector{String}`
>-  `hash(<:AbstractPermission)::UInt64`

#### Usage API 

- `name(permission::Permission)`
- `scope(permission::Permission)`
- `actions(permission::Permission)`
- `resources(permission::Permission)`
- `description(permission::Permission)`
- `iswildcard(permission::Permission)`

**Base**
- `Base.string(p::Permission)`
- `Base.hash(permission::AbstractPermission)`
-  `Base.isequal(a::AbstractPermission, b::AbstractPermission; kwargs...)`
- `Base.in(perm::AbstractPermission, perms::Vector{<:AbstractPermission})`

**DataFrame**
- `DataFrames.DataFrame(permission::Permission; flatten::Bool=false, kwargs...)`
- `DataFrames.DataFrame(permissions::Vector{Permission}; kwargs...)`

When `flatten=true`, deconstruct permissions to `resource => action`.

See also: [unwind](#unwind)

**authorisation**
- `isauthorised(perms::Vector{<:AbstractPermission}, permission::AbstractPermission; kwargs...)`
- `isauthorised(subject::AbstractPermission, permission::AbstractPermission; kwargs...)`

**unwind** <div id='unwind'/>

Deconstruct permission based on permission resources. If `flatten == true`, deconstruct also based on actions
- `unwind(permission::P; flatten::Bool=false)`
```bash
julia> FlatRBAC.unwind(Permission("user_read:api,db:read,list"))
2-element Vector{Permission}:
 Permission("user_read", ["api"], ["read", "list"], "", FlatRBAC.None)
 Permission("user_read", ["db"],  ["read", "list"], "", FlatRBAC.None)
 
julia> FlatRBAC.unwind(Permission("user_read:api,db:read,list"), flatten=true)
4-element Vector{Permission}:
 Permission("user_read", ["api"], ["read"], "", FlatRBAC.None)
 Permission("user_read", ["api"], ["list"], "", FlatRBAC.None)
 Permission("user_read", ["db"],  ["read"], "", FlatRBAC.None)
 Permission("user_read", ["db"],  ["list"], "", FlatRBAC.None)
```