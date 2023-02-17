using  FlatRBAC
import FlatRBAC.Subject
import FlatRBAC.roles

rand_perms = [random_permission() for _ in 1:10]
 
@testset "Subject" begin 
    default_id = randstring(10)
    rand_role  = random_role(rand_perms, rand(1:length(rand_perms)))
    test_subject = Subject(id=default_id, roles=[rand_role])

    @testset "Subject defintions" begin
        @test test_subject.id == default_id && test_subject.name == default_id
    end
    @testset "Subject accessors" begin 
        @test FlatRBAC.name(test_subject) == test_subject.name
        @test FlatRBAC.id(test_subject) == test_subject.id
        @test all(x->x in FlatRBAC.permissions(test_subject), permissions(rand_role))
    end
    @testset "Subject grant and revoke" begin
        default_id = randstring(10)
        rand_role  = random_role(rand_perms, rand(1:length(rand_perms)))
        test_subject = Subject(id=default_id)
        grant!(test_subject, rand_role)
        @test rand_role in roles(test_subject)

        revoke!(test_subject, rand_role)
        @test isempty(roles(test_subject))
    end
end