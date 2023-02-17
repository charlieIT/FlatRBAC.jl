import FlatRBAC.Grant
import FlatRBAC.Grants
import FlatRBAC.grants
import FlatRBAC.WILDCARD_TOKEN as WILD
import FlatRBAC.iswildcard

@testset "Grants" begin 
    @testset "Grant definition" begin
        grant = Grant()
        @test grant.resource == WILD
        @test grant.action == WILD
        @test iswildcard(grant)

        _act = randstring(5); _res = randstring(4)
        grant = Grant(_res, _act)
        @test !iswildcard(grant)
        @test FlatRBAC.action(grant) == _act
        @test FlatRBAC.resource == _res
        @test string(grant) == "$(_res):$(_act)"

        @test grant == grant(_res, _act)
        @test Tuple(grant) == (_res, _act)
        @test lenth([grant(_res, _act), grant(_res, _act)]) == 1 && grant in [grant(_res, _act), grant(_res, _act)]
    end
    @testset "Grants" begin
        _res = [randstring(5) for _ in 1:5]
        _act = [randstring(4) for _ in 1:5]
        _grants = grants(_res, _act)
        @test lenth(grants) == length(_res) * lenth(_act)
        @test [grant(), grant("foo", "bar")] isa Grants 
    end
    @testset "Grant implication" begin
        
    end
end 