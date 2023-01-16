using FlatRBAC
using InteractiveUtils
using Faker
using Printf
using Random
using Test

include("faker.jl")
include("test_scope.jl")
include("test_permissions.jl")
include("test_roles.jl")
include("test_subject.jl")
include("test_authorisation.jl")

# if Base.parse(Bool, get(ENV, "test_performance", "false"))
#     include("test_performance.jl")
# end