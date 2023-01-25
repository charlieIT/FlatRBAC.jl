using FlatRBAC
using JSON3
using Random

using HTTP
import HTTP.Handlers.cookie_middleware as CookieMiddleware

#= Setup RBAC Roles =#
guest  = Role("guest", Permission(":*:view:all"))

editor = Role("editor",  Permission(":*:update:own"))
grant!(editor, guest) # grant guest grants to editor

const roles = [guest, editor]

#= Setup some subjects =#
const users = [
    Subject(id="anonymous", roles=roles["guest"]),
    Subject(id="Person",    roles=roles["editor"])
]

#= 
Setup a simple authentication base

Mockup, not actual production code 
=#
const authentication = Dict(
    "Person" => "verySafeCredential"
)
const COOKIENAME = "app"

#= Mockup web session logic =#
SESSIONS = Dict{String, HTTP.Cookies.Cookie}()

#= !Mockup, not actual production code =#
function login(req::HTTP.Request)
    payload = JSON3.read(String(req.body))
	# Payload as {'username':'<user>', 'credential':'<credential>'}
    if string(payload["username"]) in keys(authentication)
        if string(payload["credential"]) == authentication[payload["username"]]
            cookie = HTTP.Cookies.Cookie(COOKIENAME, randstring(12))
            # Mockup session with username => cookie
            SESSIONS[payload["username"]] = cookie
            # Respond with the cookie
            return HTTP.Response(200, ["Set-Cookie"=>HTTP.stringify(cookie)])
        end
    end
    return HTTP.Response(401, "Unauthorized")
end

function SessionMiddleware(handler)
    return function(req::HTTP.Request)
        uname = "anonymous"

        cookiejar = HTTP.Handlers.cookies(req)
        match = findfirst(x->x.name == COOKIENAME, cookiejar)
        if !isnothing(match)
            appcookie = cookiejar[match]
            user = filter(kv->kv.second.value == appcookie.value, SESSIONS)
            if isempty(user)
                return HTTP.Response(401, "Unauthorized")
            end
            uname = first(user).first
        end

        req.context[:user] = users[findfirst(x->x.id == uname, users)]
        return handler(req)
    end
end

function ViewResource(req::HTTP.Request)
    resource = string(req.context[:params]["resource"])
    user     = req.context[:user]

    # Both anonymous and authenticated users can view the resource
    if !isauthorised(user, ":$resource:view")
        return HTTP.Response(401, "Unauthorized")
    end
    return HTTP.Response(200, "Welcome $(user.name)! You can view $resource")
end

function EditResource(req::HTTP.Request)
    resource = string(req.context[:params]["resource"])
    user     = req.context[:user]

    # Only users with edit permissions over the resource can POST
    if !isauthorised(user, ":$resource:update:own")
        return HTTP.Response(401, "Unauthorized")
    end

    return HTTP.Response(200, "Authorized to edit $resource")
end

# Only the user itself can view its profile
function ViewProfile(req)
    profile = string(req.context[:params]["user"])
    if !(profile in keys(authentication))
        # user does not exist in authentication store
        return HTTP.Response(404, "Unknown user $profile")
    end 
    # checking an Own permission will require an additional ownership check 
    if isauthorised(req.context[:user], ":user:view:own") &&
       # Check whether it's the actual user attempting to access their profile
       req.context[:user].id == profile 

       user = req.context[:user]
       user_roles = join(FlatRBAC.name.(FlatRBAC.roles(user)), ", ")
       return HTTP.Response(200, "Welcome $(user.name)! Your roles are $(user_roles)")
    end

    return HTTP.Response(401, "Unauthorized")
end

router = HTTP.Router((x->HTTP.Response(404)), (x->HTTP.Response(405)))

HTTP.register!(router, "GET",   "/books/{resource}/", ViewResource)
HTTP.register!(router, "POST",  "/books/{resource}/", EditResource)
HTTP.register!(router, "GET",   "/users/{user}/", ViewProfile)
HTTP.register!(router, "POST",  "/login", login)

empty!(HTTP.COOKIEJAR)
middleware = router |> CookieMiddleware |> SessionMiddleware
server = HTTP.serve!(middleware, "0.0.0.0", 80)

# Anonymous can view book resources
@info HTTP.get("http://localhost/books/Julia")
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Transfer-Encoding: chunked
│ 
└ Welcome anonymous! You can view Julia"""
=#

# Anonymous users cannot see user profiles
@info HTTP.get("http://localhost/users/Person"; status_exception = false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 401 Unauthorized
│ Transfer-Encoding: chunked
│ 
└ Unauthorized"""
=#
# Attempt to access invalid user profile
@info HTTP.get("http://localhost/users/random"; status_exception = false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 404 Not Found
│ Transfer-Encoding: chunked
│ 
└ Unknown user random"""
=#

# Login to the mini web app as the editor user
@info HTTP.post("http://localhost/login", body=JSON3.write(Dict("username"=>"Person", "credential"=>"verySafeCredential")), cookies=true)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Set-Cookie: app=<randstring>
│ Transfer-Encoding: chunked
│ 
└ """
=#

# Users can see their profiles
@info HTTP.get("http://localhost/users/Person"; cookiejar = HTTP.COOKIEJAR)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Transfer-Encoding: chunked
│ 
└ Welcome Person! Your roles are editor"""
=#

# Users can post to resources
@info HTTP.post("http://localhost/books/FooBar"; cookiejar = HTTP.COOKIEJAR)
#=┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Transfer-Encoding: chunked
│ 
└ Authorized to edit FooBar"""
=#

# HTTP.close(server)
