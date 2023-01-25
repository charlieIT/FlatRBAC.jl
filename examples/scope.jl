abstract type MyScope <:FlatRBAC.Scope end

scoped = Permission("example:resource:read:myscope")

abstract type App <:MyScope end
abstract type API <:MyScope end

# MyScope grants access to its subtypes
isauthorised(Permission(":resource:crud:myscope"), Permission(":resource:crud:app"), scoped=true) # true
isauthorised(Permission(":resource:crud:myscope"), Permission(":resource:crud:api"), scoped=true) # true

# App does not grant access to API
isauthorised(Permission(":resource:crud:app"), Permission(":resource:crud:api"), scoped=true) # false

# Both App and API grant access to Own and additional possession checks should be performed at application level
isauthorised(Permission(":resource:crud:app"), Permission(":resource:crud:own"), scoped=true) # true
isauthorised(Permission(":resource:crud:api"), Permission(":resource:crud:own"), scoped=true) # true