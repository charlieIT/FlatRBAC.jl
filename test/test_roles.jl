import FlatRBAC.Scope as Scope

RoleInterfaceMethods = [FlatRBAC.name, FlatRBAC.description, FlatRBAC.permissions, Base.hash]


@testset "Roles" begin

    @testset "Role definition" begin
        test_role = Role(name=Faker.job(), description=Faker.text())
        @test isempty(test_role)

        test_perm = Permission(permission_str())
        test_role = Role(
            Faker.job(),
            Faker.text(),
            [
                Permission(permission_str()),
                Permission(permission_str()),
                test_perm,
            ]
        )
        @test length(test_role.permissions) == 3

        @test length(Role(Faker.job(), Faker.text(), [test_perm, test_perm]).permissions) == 1 # duplicates are ignored

        _perm_1 = Permission(permission_str())
        _perm_2 = Permission(permission_str())
        _role_  = Role(name="name", permissions=[_perm_1, _perm_2])
        _role_2 = Role(name=_role_.name, permissions=[_perm_2, _perm_1])

        @test _role_ == _role_2
        @test FlatRBAC.name(_role_) == FlatRBAC.name(_role_2)
        @test FlatRBAC.description(_role_) == FlatRBAC.description(_role_2)
        @test setdiff(Set(FlatRBAC.permissions(_role_)), Set(FlatRBAC.permissions(_role_2))) |> isempty
        
        @test _role_ in [_role_, test_role] && _role_2 in [test_role, _role_2] && _role_2 in [_role_] # Base.in Role -> Roles
        @test all(x->x, [perm in role for role in [_role_, test_role] for perm in permissions(role)]) # Base.in Permission -> Role
        @test all(x->_role_[x] == x, permissions(_role_)) && all(x->_role_2[x] == x, permissions(_role_2)) # getindex
    end

    @testset "Role operations" begin
        role  = Role(name="test")
        perms = [random_permission() for _ in 1:5]
        FlatRBAC.grant!(role, perms...)
        @test all(p->p in FlatRBAC.permissions(role), perms)
        
        # --- grant! permissions via shorthand strings
        other_role = Role(name="test")
        FlatRBAC.grant!(other_role, string.(perms)...)
        @test all(p->p in FlatRBAC.permissions(other_role), perms)

        @testset "Role accessors" begin
            str_permissions = FlatRBAC.permissions(role, shorthand=true)
            @test all(p->string(p) in str_permissions, FlatRBAC.permissions(role))
        end

        @testset "Grant and revoke" begin 
            
            @test all(p->p in role, perms)
            FlatRBAC.revoke!(role, perms...)
            @test isempty(FlatRBAC.permissions(role))
        end
        @testset "Extend and revoke" begin
            Faker.seed()
            
            FlatRBAC.grant!(role, perms...)
            base_perm = random_permission()
            extend = Role(name="extend")

            FlatRBAC.grant!(extend, base_perm)
            FlatRBAC.extend!(extend, role)

            @test all(p->p in FlatRBAC.permissions(extend), FlatRBAC.permissions(role)) # all permissions from role were added to extend
            revoke!(extend, role)
            @test length(extend.permissions) == 1 && first(FlatRBAC.permissions(extend)) == base_perm 
            

        end
    end
end