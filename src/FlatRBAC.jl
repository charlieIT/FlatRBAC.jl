module FlatRBAC

    using DataFrames
    using InteractiveUtils
    using Printf
    using Random
    using Revise

    export Permission, Role, Subject
    export extend!, grant!, revoke!
    export isauthorised, authorise
    export actions, implies, permissions, resources, roles, scope
    export iswildcard

    include("exceptions.jl")
    include("utils.jl")
    include("Scope.jl")
    include("Permission.jl")
    include("Role.jl")
    include("Subject.jl")
    include("Authorisation.jl")

    #= Documentation for methods =#
    function iswildcard     end
    function implies        end
    function isauthorised   end
    function authorise      end

end