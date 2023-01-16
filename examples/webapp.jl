using FlatRBAC

# A simple example user model
struct User
  name::String
  username::String
  contact::String
end
# Example user
user = User("Mr. Admin", "admin", "Admin@example.com")

# A custom permission model
struct MyPermission <:FlatRBAC.AbstractPermission
  activity::String
  resources::Vector{Symbol}
end
abstract type MyApp <:FlatRBAC.Scope end

#= AbstractPermission interface =#
FlatRBAC.name(custom::MyPermission)      = Base.string(MyPermission)
FlatRBAC.scope(custom::MyPermission)	   = MyApp # all MyPermission instances will map to this scope
FlatRBAC.actions(custom::MyPermission)   = [custom.activity]
FlatRBAC.resources(custom::MyPermission) = string.(custom.resources)

# Example permissions
edit_projects   = MyPermission("edit", [:projects])
read_resources  = MyPermission("read", [:projects, :api])

# A custom model for role 
struct MyRole <:FlatRBAC.AbstractRole
  _id::String
  permission::Dict{String, MyPermission}
end
#= AbstractRole interface =#
FlatRBAC.name(role::MyRole) = role._id
FlatRBAC.description(role::MyRole) = "This is an example role"
FlatRBAC.permissions(role::MyRole) = collect(values(role.permission))

# Example role
custom_role = MyRole("example", Dict("edit_projects"=>edit_projects, "read_resources"=>read_resources))

#= Mockup MyDB module to store and access data =#
module MyDB
  export get 

  import Main.MyRole as MyRole
  import Main.MyPermission as MyPermission
  import Main.User as User
  import Main.edit_projects as edit_projects
  import Main.read_resources as read_resources
  import Main.custom_role as example_role

  senior_role  = MyRole("senior",  Dict("edit"=>edit_projects, "read"=>read_resources))
  junior_role  = MyRole("junior",  Dict("read"=>read_resources))

  UserRoles = Dict{User, Vector{MyRole}}
  AccessList = UserRoles(
    User("Mr. Admin", "admin", "Admin@example.com")     => [example_role],
    User("Mr. Senior", "senior", "seniore@example.com") => [junior_role, senior_role],
    User("Junior", "junior", "junior@example.com")      => [junior_role])

  function get(::Type{T}, args...; kwargs...) where T end
  
  """Obtain user from username"""
  function get(::Type{User}, uname::String) 
    return filter(u->Base.getproperty(u, :username) == string(uname), collect(keys(AccessList)))
  end
  get(::Type{User}, user::User) = get(User, user.username)

  """Obtain user roles from username"""
  function get(::Type{MyRole}, uname::String)::Vector{MyRole}
    user = get(User, uname)
    if !isempty(user)
      return values(AccessList[user[1]])
    end
    return MyRole[]
  end
  get(::Type{MyRole}, user::User) = get(MyRole, user.username)
end
#= End example MyDB =#

#= Subject interface implementation =#
function FlatRBAC.roles(user::User)::Vector{MyRole}
  return MyDB.get(MyRole, user) # example code, could just return `custom_role`
end
function FlatRBAC.Subject(user::User)
  return Subject(id=user.name, name=user.username, roles=roles(user))
end
function FlatRBAC.permissions(user::User; kwargs...)
  out = vcat([FlatRBAC.permissions(role) for role in FlatRBAC.roles(user)]...)
end

function FlatRBAC.isauthorised(user::User, args...; kwargs...)
  return FlatRBAC.isauthorised(Subject(user), args...; kwargs...)
end

#= Tests =#
@assert isauthorised(user,  MyPermission("read", [:projects])) "Failed :projects:read"
# true
@assert !isauthorised(user, MyPermission("read", [:random])) "Failed :random:read"
# false
@assert isauthorised(user,  MyPermission("edit", [:projects])) "Failed :projects:edit"
# true
@assert isauthorised(user,  MyPermission("read", [:projects, :api])) "Failed :api,projects:read"
# true
@assert !isauthorised(user, Permission(":api:edit")) "Failed :api:edit"
#false

#= Web Example =#
using HTTP # version >= 1.0.0

function authorisation(handler)
  return function(req)
    uname = HTTP.getparam(req, "user", nothing)
    resource = HTTP.getparam(req, "resource", nothing)
    
    if uname === nothing || resource === nothing
      return HTTP.Response(401, "Unauthorized")
    end
    
    user = MyDB.get(User, uname)
    if isempty(user)
      return HTTP.Response(401, "Unauthorized")
    end
    user = user[1]
    # Check if user is granted read access to this resource type
    if !FlatRBAC.isauthorised(user, Permission(resources=[string(resource)], actions=["read"])) 
      return HTTP.Response(401, "Unauthorized")
    end
    req.context[:subject]  = user
    req.context[:resource] = string(resource)
    return handler(req)
  end
end

function handler(req)
	uname = req.context[:subject].username
	res   = req.context[:resource]
	return HTTP.Response(200, "Welcome $(uname)! You can access $res")
end

router = HTTP.Router((x->HTTP.Response(404)), (x->HTTP.Response(405)))
HTTP.register!(router, "GET", "/{user}/{resource}", authorisation(handler))
server = HTTP.serve!(router, "0.0.0.0", 80)

# HTTP.close(server)
