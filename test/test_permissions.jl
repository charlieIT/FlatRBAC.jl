import FlatRBAC.Scope as Scope
import FlatRBAC.iswildcard as iswildcard

PermissionInterfaceMethods = [FlatRBAC.name, FlatRBAC.scope, FlatRBAC.actions, FlatRBAC.resources, FlatRBAC.description, Base.hash]

@testset "Permissions" begin

    @testset "Permission definition" begin
        long = Permission(name="admin", resources=["*"], actions=["create", "read", "update", "delete"], scope=FlatRBAC.All, description="CRUD Admin")
        shorthand = Permission("admin:*:create,read,update,delete:all", "CRUD Admin") # spaces to test for correct strip
        @test Base.hash(long) == Base.hash(shorthand) && long == shorthand
        @test string(long) == string(shorthand) == "admin:*:create,read,update,delete:all"

        @test !iswildcard(long) && !iswildcard(shorthand)
        @test iswildcard(Permission(":*:*")) && iswildcard(Permission())
        
        @test_throws FlatRBAC.InvalidPermissionExpression   Permission("")  
        @test_throws FlatRBAC.InvalidPermissionExpression   Permission(FlatRBAC.DIVIDER_TOKEN) 
        @test_throws FlatRBAC.InvalidPermissionExpression   Permission(FlatRBAC.SEPARATOR_TOKEN)
        @test_throws FlatRBAC.InvalidPermissionExpression   Permission(random_invalid_permission_str()) 

        @test all(method->method(long) == method(shorthand), PermissionInterfaceMethods)
    end

    @testset "Permission operations" begin
    end
end