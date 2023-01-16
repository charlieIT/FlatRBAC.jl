function gen_str_token(length::Int)
    return repeat("?", length)
end

function gen_permission_token(length::Int=1)
    return repeat(Faker.random_element((FlatRBAC.DIVIDER_TOKEN, FlatRBAC.SUBPART_DIVIDER_TOKEN)), length)
end

function random_invalid_permission_str(length::Int=Random.rand(1:10))
    return join(
            shuffle!(
                [Faker.random_element(
                    (FlatRBAC.DIVIDER_TOKEN, FlatRBAC.SUBPART_DIVIDER_TOKEN)) 
                for _ in 1:length])
            )
end

function random_resources(howmany::Int=1; length::Int=4)
    token = gen_str_token(length)
    return [Faker.lexify(token) for _ in 1:howmany]
end

function random_actions(howmany::Int=1; length::Int=4)
    return [Faker.word() for _ in 1:howmany]
end

function random_description(chars::Int=50)
    return Faker.text(number_chars=chars)
end

function permission_str(;
    name::String = Faker.job(),
    actions::Vector{String} = random_actions(),
    resources::Vector{String} = random_resources(),
    description::String = random_description(),
    scope::Type{<:FlatRBAC.Scope} = FlatRBAC.None)

    return @sprintf "%s:%s:%s:%s" name join(resources, ",") join(actions, ",") lowercase(string(scope))
end

function random_permission(res::Int=rand(1:10), acts::Int=rand(1:10))
    return FlatRBAC.Permission(
            name = Faker.job(),
            actions = random_actions(acts),
            resources = random_resources(res),
            description = random_description(5),
            scope = Faker.random_element(Tuple([FlatRBAC.All, FlatRBAC.Own, FlatRBAC.None]))
        )
end
function random_subject()
    return FlatRBAC.Subject(id=randstring(10))
end
function random_role(permissions::Vector{<:FlatRBAC.AbstractPermission}, length::Int=1)
    perms = shuffle(permissions)[1:length]
    return Role(
        name  = randstring(10),
        permissions = perms 
    )
end