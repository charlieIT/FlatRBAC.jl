using FlatRBAC
using JSON3
using Random

using HTTP
import HTTP.Handlers.cookie_middleware as CookieMiddleware

#= Setup RBAC Roles =#
guest  = Role("guest", Permission(":*:view:all"))

#= Setup some subjects =#
const users = [
    Subject(id="anonymous"), # no roles
    Subject(id="guest", roles=[guest])
]

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

function handler(req::HTTP.Request)
	uname = req.context[:subject].name
    resource = req.context[:resource]

	return HTTP.Response(200, "Welcome $(uname)! You can access $(resource)")
end

router = HTTP.Router((x->HTTP.Response(404)), (x->HTTP.Response(405)))
HTTP.register!(router, "GET",  "/api/{resource}", Authorisation(handler))
HTTP.register!(router, "POST", "/login", MockupLogin)

empty!(HTTP.COOKIEJAR)
server_middleware = router |> CookieMiddleware |> SessionMiddleware
server = HTTP.serve!(server_middleware, "0.0.0.0", 80)

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
@info HTTP.get("http://localhost/api/books"; cookiejar = HTTP.COOKIEJAR, status_exception=false)
#=
┌ Info: HTTP.Messages.Response:
│ """
│ HTTP/1.1 200 OK
│ Transfer-Encoding: chunked
│ 
└ Welcome guest! You can access books"""
=#

# HTTP.close(server)