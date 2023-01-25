permA = [Permission(":projects:read"), Permission(":documents:export")]
RoleA = Role(name="A", permissions=permA)

# A does not grant edit privileges over documents
@assert !isauthorised(RoleA, Permission(":documents:edit")) # A does not grant edit privileges over documents

permB = [Permission(":projects,documents:read,edit")]
RoleB = Role(name="B", permissions=permB)

permC = [Permission(":api:list")]
RoleC = Role(name="C", permissions=permC)

# Extend `A` with permissions from `B` and `C`
extend!(RoleA, RoleB, RoleC) # Extend `A` with permissions from `B` and `C`

# now it is possible, as RoleA obtained this privilege from RoleB
@assert isauthorised(RoleA, Permission(":documents:edit")) # now it is possible, as RoleB was granted this privilege

#= Revocation =#

# Revoke permissions of `B` from `A`
revoke!(RoleA, RoleB)
# no longer possible
@assert !isauthorised(RoleA, Permission(":documents:edit")) # no longer possible

example = Role(name="Example")
grant!(example,  Permission("read_all:*:read"))
# 1-element Vector{Permission}: Permission("read_all", ["*"], ["read"], "", FlatRBAC.None)

revoke!(example, Permission("read_all:*:read"))
#Permission[]