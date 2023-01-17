using FlatRBAC

third_party   = Subject(id="3rdPartyApi")

read_database = Permission(name="read_db", resources=["database"], actions=["read", "list"])
create_key    = Permission("create-key:api-key:create")

third_party_role = Role(name="3rdPartyApi")
grant!(third_party_role, read_database, create_key)

# Alternatively, 
# third_party_role = Role(name="3rdPartyApi", permissions=[read_database, create_key])

grant!(third_party, third_party_role)

@assert isauthorised(third_party,  ":database:read")   "Failed :database:read" # true
@assert isauthorised(third_party,  ":api-key:create")  "Failed :keys:create" # true
@assert !isauthorised(third_party, ":database:delete") "Failed admin:database:delete" # false