# FlatRBAC

FlatRBAC provides a Julia implementation for the [first level of the NIST model for role based access control](https://www.nist.gov/publications/nist-model-role-based-access-control-towards-unified-standard) and aims to ease the process of defining, enforcing and maintaining security policies.

The package _embodies the essential aspects of RBAC_, as described in the model:

 - Many to many subject-role assignment 
 - Many to many permission-role assignment
 - Subjects acquire permissions through roles
 - Subject-role assignment review
 - Subjects may exercise permissions of multiple roles

and it also adds some **additional features**:

 - Multi-action, multi-resource permissions
 - Define and exert access control on domains

In the context of this package, neither active role restrictions, hierarchy, nor sessions are implemented.

## Project status 

The package is under active development and changes may occur.

## Contributions, suggestions, questions

All are welcome, as well as feature requests and bug reports. Please open an issue or a PR.

## Table of Contents
1. [Installation](#installation)
2. [Usage example](#usage-example)
3. [Concept overview](#concept-overview)<br/>
	- [Permission](#permission)<br/>
	- [Scope](#scope)<br/>
	- [Role](#role)<br />
	- [Subject](#subject)
	- [Authorisation](#authorisation)
4. [Additional examples](#additional-examples)


## Installation

The package can be installed via package manager
```
pkg> add FlatRBAC
```
It can also be installed by [providing a URL to the repository](https://pkgdocs.julialang.org/v1/managing-packages/#Adding-unregistered-packages)
```bash
pkg> add https://github.com/charlieIT/flatrbac.jl
```

## Usage example
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
create_key    = Permission("create-key:api-key:create") # `name:resources:actions`
```
**Create roles and grant permissions**
```julia
third_party_role = Role(name="3rdPartyApi")
grant!(third_party_role, read_database, create_key)

# Alternatively, 
third_party_role = Role(name="3rdPartyApi", permissions=[read_database, create_key])
```
**Grant roles to a subject**
```julia
grant!(third_party, third_party_role)
```
**Check if a subject is authorised**
```julia
isauthorised(third_party, ":database:read")   # true
isauthorised(third_party, ":api-key:create")  # true
isauthorised(third_party, ":database:delete") # false
```
## Concept overview

### [Permission](@ref)

A `Permission` is a mechanism for authorisation, specifying `actions` a given `subject` can perform over `resources`. 

Permissions may be defined in `shorthand` form as `<name>:<resources>:<actions>:<scope>`.
```bash
julia> cruds = Permission(name="admin", resources=["*"], actions=["create", "read", "update", "delete"], scope=FlatRBAC.All, description="CRUD Admin")
Permission("admin", ["*"], ["create", "read", "update", "delete"], "CRUD Admin", FlatRBAC.None)

julia> shorthand = Permission("admin:*:create,read,update,delete:all", "CRUD Admin")
Permission("admin", ["*"], ["create", "read", "update", "delete"], "CRUD Admin", FlatRBAC.None)
```

Permissions default to wildcard values (`"*"`) for both `resources` and `actions`
```julia
julia> Permission()

Permission(:*:*:none)
```
Permissions are always positive and grant all specified actions to each resource
```julia
example = Permission(":any:c,r,u,d")
# example is granted (any:c), (any:r), (any:u), (any,d)
for action in actions(example)
  @assert isauthorised(example, Permission(":any:$(action)")) "Should not fail"
end
```
See also [permission docs](/docs/Permission.md).

------------------

### [Scope](@ref) 

Scopes allow binding of permissions to custom _domain/tenants_ and can also be used for possession checks.

Permissions default to scope `None`:
```bash
julia> Permission("example:resource:action")

Permission("example", ["resource"], ["action"], "", FlatRBAC.None)
```

The package provides implementation for three base scopes: 

`FlatRBAC.All - Type`

- This scope acts as an `wildcard` and will, by default, grant access to any other scope.

`FlatRBAC.Own - Type`

- Own and Own subtypes are useful for dealing with **resource possession** and should be used in conjunction with ownership/possession checks in the application logic.

`FlatRBAC.None - Type`

- This is the default scope and will, by default, only grant access to the None scope.

The package provides default behaviour for `Scope` subtypes
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

MyScope grants access to its subtypes
```julia
isauthorised(Permission(":resource:crud:myscope"), Permission(":resource:crud:app"), scoped=true) # true
isauthorised(Permission(":resource:crud:myscope"), Permission(":resource:crud:api"), scoped=true) # true
```
App does not grant access to API
```julia
isauthorised(Permission(":resource:crud:app"), Permission(":resource:crud:api"), scoped=true) # false
```
Both App and API grant access to Own and additional possession checks should be performed at application level
```julia
isauthorised(Permission(":resource:crud:app"), Permission(":resource:crud:own"), scoped=true) # true
isauthorised(Permission(":resource:crud:api"), Permission(":resource:crud:own"), scoped=true) # true
```
For additional notes and performance considerations, see also the [scope docs](/docs/Scope.md).

----------------

### [Role](@ref)

`Roles` define an authority level or function within a context. These are usually defined in accordance with job competency, authority or responsability. 

In this package, roles are collection of permissions that can be assigned to `subjects`, allowing them to perform `actions` over `resources`.

**Roles can extend other roles**
```julia
permA = [Permission(":projects:read"), Permission(":documents:export")]
RoleA = Role(name="A", permissions=permA)

julia> permissions(RoleA)
2-element Vector{Permission}:
 Permission(:projects:read:none)
 Permission(:documents:export:none)

# A was not granted edit privileges over documents
@assert !isauthorised(RoleA, Permission(":documents:edit"))
```
```julia
permB = [Permission(":projects,documents:read,edit")]
RoleB = Role(name="B", permissions=permB)

permC = [Permission(":api:list")]
RoleC = Role(name="C", permissions=permC)

# Extend `A` with permissions from `B` and `C`
julia> extend!(RoleA, RoleB, RoleC) 
4-element Vector{Permission}:
 Permission(:projects:read,edit:none)
 Permission(:documents:export:none)
 Permission(:documents:read,edit:none)
 Permission(:api:list:none)

# now it is possible, as RoleA obtained this privilege from RoleB
@assert isauthorised(RoleA, Permission(":documents:edit")) 
```
**Both permissions and roles can be revoked from a `Role`**
```julia
# Revoke permissions of `B` from `A`
revoke!(RoleA, RoleB)
# no longer possible
@assert !isauthorised(RoleA, Permission(":documents:edit")) # no longer possible
```
```julia
example = Role(name="Example")
grant!(example,  Permission("read_all:*:read"))
# 1-element Vector{Permission}: Permission(read_all:*:read:none)

revoke!(example, Permission("read_all:*:read"))
# Permission[]
```
**Note:** As of `v.0.1` and `v0.2` revocation is performed based on permission equality. In the future, revocation will ensure any permission from B that implies a permission from A is also revoked.

See also [role docs](/docs/Roles.md).

--------------------

### [Subject](@ref)

An automated agent, person or any relevant third party for which authorisation should be enforced.
```julia
role = Role(name="Example", permissions=[Permission()])
sysadmin = Subject(id="sysadmin", name="System Admin", roles=[role])
```

----------------------

### [Authorisation](@ref)

The process of verifying whether a given `subject` is allowed to access and perform specific `actions` over a `resource`. 

In `FlatRBAC`, **subjects may exercise permissions of multiple roles**. Authorisation logic will default to this behaviour, i.e., (*pseudo-code*) `granted(user, permission) = granted(permissions(subject), permission)`, regardless of the roles or specific permissions that will satisfy the condition.

However, when authorising, you can specify whether authorisation should only be granted if `permission` is granted within a single role, i.e, (*pseudo-code*) `granted(user, permission) = any(x->granted(role, permission), roles(subject)`. Use `singlerole=true` to trigger this behaviour.

#### Examples

**Permission based authorisation checks**
```julia
coverage = Permission(":projects,api,database:create,read,update")
requirement = Permission(":database:create,read,update")
isauthorised(coverage, requirement) # true
```
```julia
coverage = Permission(":projects,api,database:create,read,delete") # update action is removed
# checking exactly for (create,read and update) on database
requirement = Permission(":database:create,read,update") 
isauthorised(coverage, requirement) # false
```
_Recommendation is to be wary when using complex permissions in authorisation checks._

**Subject based authorisation checks**
```julia
store_perms = [
	Permission("view-any:books,movies,music:view:all"),
	Permission("rent-books:books:rent:all"),
	Permission("update-own:books,movies,music:update:own"),
	Permission("rent-any:*:rent:all"),
	Permission("update-any:*:update:all"),
	Permission("buy:*:buy,view:all")
]
	
store_roles = [
	# Authors can view everything and update their own resources
	Role("author",   store_perms["update-own"]..., store_perms["view-any"]...),
	# Customers can temporarily rent books, view and buy anything
	Role("customer", store_perms["rent-books"]..., store_perms["buy"]...),
	# Employees can rent and update anything
	Role("employee", store_perms["rent-any"]...,   store_perms["update-any"]...)]
```
```julia
john = Subject(id="John")
grant!(john , store_roles["customer"]...) # John is a customer

# Can rent and buy books
@assert isauthorised(john, ":books:buy,rent")
# Can view books, movies and music
@assert isauthorised(john, ":books,movies,music:view")
```
Using  `single-role`
```julia
julia = Subject(id="Julia")
# Employees can also be customers
grant!(julia, store_roles["employee"]..., store_roles["customer"]...) 

# Granted rent on any resource via employee role
@assert isauthorised(julia, ":movies,music,files:rent", singlerole=true) # true
# Buy and rent for music are not granted via the same role
# Rent -> Employee role; Buy -> Customer role
@assert !isauthorised(julia, ":music:buy,rent", singlerole=true)
```

#### Usage API 

- `isauthorised(subject, permission; singlerole=false, scoped=true, kwargs...)::Bool`

## Additional examples

See also [web examples](/examples/web).

### Mini web application with authorisation middleware
```julia
using FlatRBAC
using JSON3
using HTTP
using Random

import HTTP.Handlers.cookie_middleware as CookieMiddleware
```
**Setup RBAC logic**
```julia
#= Setup RBAC Roles =#
guest = Role("guest", Permission(":*:view:all"))

#= Setup some subjects =#
const users = [
    Subject(id="anonymous"), # no roles
    Subject(id="guest", roles=[guest])
]
```
**Mockup authentication and session management**
```julia
#!Not actual production code!
const COOKIE_NAME = "app"
#= Mockup web session logic =#
SESSIONS = Dict{String, HTTP.Cookies.Cookie}()

"""Mockup login as Guest"""
function MockupLogin(req::HTTP.Request)
    cookie = HTTP.Cookies.Cookie(COOKIE_NAME, randstring(12))
    SESSIONS["guest"] = cookie
    # Respond with the cookie
    return HTTP.Response(200, ["Set-Cookie"=>HTTP.stringify(cookie)])
end
```
**Middleware to map incoming requests to an app user session**
```julia
#!Not actual production code!
"""Check request cookies for matching session"""
function SessionMiddleware(handler)
  return function(req::HTTP.Request)
    uname = "anonymous" # default to anonymous

    cookiejar = HTTP.Handlers.cookies(req)
    match = findfirst(x->x.name == COOKIE_NAME, cookiejar)
    if !isnothing(match)
        appcookie = cookiejar[match]
        user = filter(kv->kv.second.value == appcookie.value, SESSIONS)
        if isempty(user) # session open but unknown user
            return HTTP.Response(401, "Unauthorized")
        end
        uname = first(user).first
    end
    # set user and pass along the request
    req.context[:user] = users[findfirst(x->x.id == uname, users)]
    return handler(req)
  end
end
```
**Middleware to authorise access to app resources**
```julia
function Authorisation(handler)
    return function(req::HTTP.Request)
        user = req.context[:user]
        resource = string(req.context[:params]["resource"])
        
        # Check if user is granted view access to this resource
        if !FlatRBAC.isauthorised(user, Permission(":$(resource):view"))
            return HTTP.Response(401, "Unauthorized")
        end

        req.context[:subject]  = user
        req.context[:resource] = string(resource)
        return handler(req)
    end
end
```
**Mockup resource handler**
```julia
function handler(req::HTTP.Request)
    uname = req.context[:subject].name
    resource = req.context[:resource]
    
    return HTTP.Response(200, "Welcome $(uname)! You can access $(resource)")
end
```
**Setup the HTTP server**
```julia
router = HTTP.Router((x->HTTP.Response(404)), (x->HTTP.Response(405)))

HTTP.register!(router, "GET",  "/api/{resource}", Authorisation(handler))
HTTP.register!(router, "POST", "/login", MockupLogin)

empty!(HTTP.COOKIEJAR)
server_middleware = router |> CookieMiddleware |> SessionMiddleware
server = HTTP.serve!(server_middleware, "0.0.0.0", 80)
```
**Check if it works**
```julia
# Anonymous cannot view book resources
@info HTTP.get("http://localhost/api/books", status_exception=false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 401 Unauthorized
│ Transfer-Encoding: chunked
│ 
└ Unauthorized"""
=#

# Authenticate as guest
@info HTTP.post("http://localhost/login", cookies=true, status_exception=false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Set-Cookie: app=<randstring>
│ Transfer-Encoding: chunked
│ 
└ """
=#

# Guest can view books
@info HTTP.get("http://localhost/api/books"; cookiejar = HTTP.COOKIEJAR, status_exception=false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Transfer-Encoding: chunked
│ 
└ Welcome guest! You can access books"""
=#
```
```julia
# Close the server
HTTP.close(server)
```
