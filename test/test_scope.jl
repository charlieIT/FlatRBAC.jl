import FlatRBAC.Scope as Scope
import FlatRBAC.iswildcard as iswildcard

module ScopeTest
    using FlatRBAC
    abstract type TestScope <:FlatRBAC.Scope end
end

abstract type A <:FlatRBAC.Scope end
abstract type B <:A end
abstract type C <:B end

Base.string(::Type{A})      = "A"
FlatRBAC.Scope(::Val{:a})   = A
FlatRBAC.Scope(::Val{:b})   = B

abstract type MyWildcard <:FlatRBAC.Scope end
FlatRBAC.iswildcard(::Type{MyWildcard}) = true

@testset "Scope" begin 
    
    @test all(x->FlatRBAC.Scope(string(x)) == x, InteractiveUtils.subtypes(FlatRBAC.Scope)) # Default logic to obtain to Scope from string
    
    @testset "Scope creation" begin
        
        @test Base.string(ScopeTest.TestScope) == "TestScope"
        @test !iswildcard(ScopeTest.TestScope)

        abstract type _Scope <:FlatRBAC.All end
        @test !iswildcard(_Scope)
    end
    @testset "Scope interfaces" begin
        @test FlatRBAC.iswildcard(FlatRBAC.All)

        @test FlatRBAC.iswildcard(MyWildcard)
        @test FlatRBAC.implies(MyWildcard, FlatRBAC.All)
        @test all(x->FlatRBAC.implies(MyWildcard, x), [A,B,C])
    end
end

