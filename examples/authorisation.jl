coverage = Permission(":projects,api,database:create,read,update")
requirement = Permission(":database:create,read,update")
isauthorised(coverage, requirement) # true

coverage = Permission(":projects,api,database:create,read,delete") # update action is removed
# checking exactly for (create,read and update) on database
requirement = Permission(":database:create,read,update") 
isauthorised(coverage, requirement) # false

# Subject based authorisation checks
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

john = Subject(id="John")
grant!(john , store_roles["customer"]...) # John is customer

# Can rent and buy books
@assert isauthorised(john, ":books:buy,rent")
# Can view books, movies and music
@assert isauthorised(john, ":books,movies,music:view")

# Using singlerole = true
julia = Subject(id="Julia")
# Employees can also be customers
grant!(julia, store_roles["employee"]..., store_roles["customer"]...) 

# Granted rent on any resource
@assert isauthorised(julia, ":movies,music,files:rent", singlerole=true) # true
# Buy and rent for music are not granted via the same role
# Rent -> Employee role; Buy -> Customer role
@assert !isauthorised(julia, ":music:buy,rent", singlerole=true)