import FlatRBAC.Scope
import FlatRBAC.All
import FlatRBAC.None
import FlatRBAC.Own
import FlatRBAC.iswildcard as iswildcard
import FlatRBAC.implies

module ScopeTest
    using FlatRBAC
    abstract type TestScope <:FlatRBAC.Scope end
end

abstract type A <:Scope end
abstract type B <:A end
abstract type C <:B end

Base.string(::Type{A}) = "A"
Scope(::Val{:a}) = A
Scope(::Val{:b}) = B

abstract type MyWildcard <:FlatRBAC.Scope end
iswildcard(::Type{MyWildcard}) = true

abstract type SubOwn <:FlatRBAC.Own end

@testset "Scope" begin 
    
    @test all(x->FlatRBAC.Scope(string(x)) == x, InteractiveUtils.subtypes(Scope)) # Default logic to obtain to Scope from string
    
    @testset "Scope creation" begin
        
        @test Base.string(ScopeTest.TestScope) == "TestScope"
        @test !iswildcard(ScopeTest.TestScope)

        abstract type _Scope <:FlatRBAC.All end
        @test !iswildcard(_Scope)
    end
    @testset "Scope interfaces" begin
        @test iswildcard(All)

        @test iswildcard(MyWildcard)
        @test implies(MyWildcard, All)
        @test all(x->implies(MyWildcard, x), [A,B,C])
    end
    @testset "Scope implication" begin
        @test implies(Own, SubOwn) && !implies(SubOwn, Own)
        @test implies(All, Own) && implies(Own, None) && implies(All, None)
    end
end