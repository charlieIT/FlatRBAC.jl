



# FlatRBAC

FlatRBAC provides a Julia implementation for the [first level of the NIST model for role based access control](https://www.nist.gov/publications/nist-model-role-based-access-control-towards-unified-standard).

The package _embodies the essential aspects of RBAC_, as described in the model:

 - Many to many subject-role assignment 
 - Many to many permission-role assignment
 - Subjects acquire permissions through roles
 - Subject-role assignment review
 - Subjects may exercise permissions of multiple roles

and it also adds some **additional features**:

 - Multi-action, multi-resource permissions
 - Define and control access permissions on domains

In the context of this package, neither active role restrictions, hierarchy, nor sessions are implemented.

## Project status 

The package is under active development and changes may occur.

## Contributions, suggestions, questions

All are welcome, as well as feature requests and bug reports. Please open an issue or a PR.

## Table of Contents
1. [Installation and usage](#example2)
2. [Basic usage example](#basic-example)
3. [Concept overview](#concept-overview)<br/>
	- [Permission](#permission)<br/>
	- [Scope](#scope)<br/>
	- [Role](#role)<br />
	- [Subject](#subject)
	- [Authorisation](#authorisation)
4. [Advanced examples](#advanced)


## Installation

The package is currently unregistered, but can be installed via Package Manager by [providing a URL to the repository](https://pkgdocs.julialang.org/v1/managing-packages/#Adding-unregistered-packages)
```bash
pkg> add https://github.com/charlieIT/flatrbac.jl
```

## Basic usage example <div id='basic-example'/>
``` julia
using FlatRBAC
```
**Define subjects**
```julia
third_party = Subject(id="3rdPartySystem")
```
**Define permissions**
```julia
read_database = Permission(name="read_db", resources=["database"], actions=["read", "list"])
create_key    = Permission("create-key:api,keys:create")
```
**Create roles and grant permissions**
```julia
third_party_role = Role(name="3rdPartyApi")
grant!(third_party_role, read_database, create_key) 
# Alternatively, third_party_role = Role(name="3rdPartyApi", permissions=[read_database, create_key])
```
**Grant roles to a subject**
```julia
grant!(third_party, third_party_role)
```
**Check authorisation for a given permission** 
```julia
isauthorised(third_party, read_database)  # true
isauthorised(third_party, ":keys:create") # true
isauthorised(third_party, ":database:delete") # false
```
## Concept overview <div id='concept-overview'/>

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

#### `AbstractPermission - Type`

A Permission is a subtype of `AbstractPermission`, which defines the following **interface methods**:

>`name(<:AbstractPermission)::String`<br/>
>`scope(<:AbstractPermission)::Scope`<br/>
>`actions(<:AbstractPermission)::Vector{String}`<br/>
>`resources(<:AbstractPermission)::Vector{String}`<br/>
> `hash(<:AbstractPermission)::UInt64`

### Scope 
----------------

Scopes allow binding of permissions to custom _domains_ and can also be used for possession checks.

Permissions default to scope `None`:
```bash
julia> Permission("example:resource:action")

Permission("example", ["resource"], ["action"], "", FlatRBAC.None)
```

The package provides implementation for three base scopes: 

`FlatRBAC.All - Type`

This scope acts as an `wildcard` and will, by default, grant access to any other scope

`FlatRBAC.Own - Type`

Own and Own subtypes are useful for dealing with **resource possession** and should be used in conjunction with ownership/possession checks in the application logic

`FlatRBAC.None - Type`

This is the default scope and will, by default, only grant access to the None scope

#### `AbstractScope - Type`

A `Scope` is a subtype of `AbstractScope`, which defines the following **interface methods**:

>`Base.string(::Type{<:Scope})::String`<br/>
>`Scope(::Val{:lowercasename})::Scope`<br/>
>`iswildcard(::Type{<:Scope})::Bool`<br/>

The package provides default behaviour for `AbstractScope` subtypes
```julia
abstract type MyScope <:FlatRBAC.Scope end

scoped = Permission("example:resource:read:myscope")
# Permission("example", ["resource"], ["read"], "", MyScope)
```
**Examples**
```julia
abstract type App <:MyScope end
abstract type API <:MyScope end
```
```jldoctest
julia> isauthorised(Permission(":r:crud:myscope"), Permission(":r:crud:app"), scoped=true)
true
julia> isauthorised(Permission(":r:crud:app"), Permission(":r:crud:API"), scoped=true)
false
julia> isauthorised(Permission(":r:crud:app"), Permission(":r:crud:own"), scoped=true)
true
```
For performance considerations and notes, see also the [scope docs](/docs/Scope.md)

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

#### `AbstractRole- Type`

A Role is a subtype of `AbstractRole`, which defines the following interface methods:
>`name(<:AbstractRole)::String`<br/>
>`description(<:AbstractRole)::String`<br/>
>`permissions(<:AbstractRole)::Vector{<:AbstractPermission}`<br/>
> `hash(<:AbstractRole)::UInt64`

### Subject
--------------------

An automated agent, person or any relevant third party for which authorisation should be enforced.

#### `AbstractSubject - Type`

A Subject is a subtype of `AbstractSubject`, which defines the following **interface methods**:
>`id(<:AbstractSubject)::String`<br/>
>`name(<:AbstractSubject)::String`<br/>
>`roles(<:AbstractSubject)::Vector{<:AbstractRole}`<br/>
>`hash(<:AbstractSubject)::UInt64`<br/>

### Authorisation
--------------------

The process of verifying whether a given `subject` is allowed to access and perform specific `actions` over a `resource`. 

In `FlatRBAC`, **subjects may exercise permissions of multiple roles**. Authorisation logic will default to this behaviour, i.e., `granted(user, permission) = granted(permissions(subject), permission)` (*pseudo-code*), regardless of the roles or specific permissions that will satisfy the condition.

However, when authorising, you can specify whether authorisation should only be granted if `permission` exists within a single role, i.e, `granted(user, permission) = [granted(role, permission) for role in roles(subject)]` (*pseudo-code*). Use `singlerole=true` to trigger this behaviour.

#### Granting and checking for permissions 

When granting a *compound* permission,  access is granted access to all specified resources and specified actions, i.e., **AND** operator. 

Example: `≈ Permission(":projects,api,database:create,read,update")` will allow access to projects, api and database and enable create, read and update actions over each resource.

When checking for authorisation, the same logic applies:
 `granted(subject, Permission(":projects,api,database:create,read,update")` means to check a subjects' permissions for exactly these resources and exactly these actions. For instance, permission is not granted if subject is able to access projects, api and database to create and read, but not update. 

```julia
coverage = Permission(":projects,api,database:create,read,update")
requirement = Permission(":database:create,read,update")
isauthorised(coverage, requirement) # true
```
```julia
coverage = Permission(":projects,api,database:create,read,delete") # update action is removed
requirement = Permission(":database:create,read,update") # checking exactly for (create,read and update) over a database
isauthorised(coverage, requirement) # false
```
**Recommendation is to be wary when using _compound_ permissions in authorisation checks.**

#### Usage API 

- `isauthorised(subject, permission; singlerole=false, scoped=false, kwargs...)::Bool`

## Advanced usage<div id='advanced'/>

**Under construction**