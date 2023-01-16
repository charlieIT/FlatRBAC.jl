### Role
-----------------------

`Roles` define an authority level or function within a context. These are usually defined in accordance with job competency, authority, and  responsibility or responsability. For the purpose of this package, roles are collection of permissions that can be assigned to `subjects`, allowing them to perform `actions` over `resources`.

**Roles can extend other roles**
```julia
permA = [Permission(":projects:read"), Permission(":documents:export")]
A = Role(name="A", permissions=permA)

@assert !isauthorised(A, Permission(":documents:edit")) # false

permB = [Permission(":projects,documents:read,edit")]
B = Role(name="B", permissions=permB)

permC = [Permission(":api:list")]
C = Role(name="C", permissions=permC)

extend!(A, B, C) # Extend `A` with permissions from `B` and `C`

@assert isauthorised(A, Permission(":documents:edit")) # now it is possible
```
**Both permissions and roles can be revoked from a `Role `**
```julia
revoke!(A, B) # Revoke permissions of `B` from `A`
@assert !isauthorised(A, Permission(":documents:edit")) # no longer possible
```
```julia
example = Role(name="Example")
grant!(example,  Permission("read_all:*:read"))
# 1-element Vector{Permission}: Permission("read_all", ["*"], ["read"], "", FlatRBAC.None)
revoke!(example, Permission("read_all:*:read"))
# Permission[]
```
**Note:** As of `v.0.1.0` revocation is only performed based on permission equality. In the future, revocation will ensure any permission from B that implies a permission from A is also revoked.

#### Interface methods

**A Role is a subtype of `AbstractRole`, which defines the following interface methods**:
>- `name(<:AbstractRole)::String`
>- `description(<:AbstractRole)::String`
>- `permissions(<:AbstractRole)::Vector{<:AbstractPermission}`
>-  `hash(<:AbstractRole)::UInt64`

#### Usage API 

- `name(role::Role)`
- `description(role::Role)`
- `permissions(role::Role; shorthand::Bool=false)`

**extend!**
- `extend!(base::Role, role::AbstractRole)`
- `extend!(base::Role, roles::AbstractRole...)`

**grant!**

- `grant!(role::Role, permission::AbstractPermission)`
- `grant!(base::Role, grants::AbstractPermission...)`
-  `grant!(base::Role, grants::String...)`
- `grant!(base::Role, roles::AbstractRole...)`

**revoke!**
- `revoke!(base::Role, permission::AbstractPermission)`
- `revoke!(base::Role, role::AbstractRole)`

**DataFrame** 
- `DataFrames.DataFrame(role::Role; kwargs...)`
- `DataFrames.DataFrame(roles::Vector{Role}; kwargs...)`

**authorisation**
- `isauthorised(roles::Vector{<:AbstractRole}, permission::AbstractPermission; kwargs...)`
- `isauthorised(role::AbstractRole, permission::AbstractPermission; kwargs...)`