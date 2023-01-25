# Authorisation

## [Granting and checking for permissions](@ref)

When granting a permission, access is granted to all specified resources with specified actions, i.e., **AND** operator.

*pseudo-code example*
```julia
grants(Permission(":api,database:create,read")) ≈ (("api", "create"), ("api", "read"), ("db", "create"), ("db", "read"))
```
This will enable access to both api and database resources, allowing read and create actions over each resource.

When checking for authorisation, the same logic applies:<br/>
`granted(subject, Permission(":api,database:create,read,update")`
means to check a subjects' permissions for exactly these resources and exactly these actions. For instance, permission is not granted if subject is able to access api and database to create and read, but not update. 