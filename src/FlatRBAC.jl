module FlatRBAC

    using DataFrames
    using InteractiveUtils
    using Printf
    using Revise

    export Permission, Role, Subject
    export extend!, grant!, revoke!
    export isauthorised, authorise
    export actions, name, permissions, resources, roles, scope
    export iswildcard

    include("exceptions.jl")
    include("utils.jl")
    include("Grant.jl")
    include("Scope.jl")
    include("Permission.jl")
    include("Role.jl")
    include("Subject.jl")
    include("Authorisation.jl")

    #= Method documentation =#
    function grant!         end
    function revoke!        end
    """
        iswildcard(str::String)
        iswildcard(::Type{<:Scope})
        iswildcard(permission::Permission)
        iswildcard(grant::Grant)
    """
    function iswildcard     end
    function implies        end
    function isauthorised   end

end
