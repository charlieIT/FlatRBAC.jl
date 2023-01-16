### Scope 
----------------

Scopes allow binding of permissions to custom _domains_ and can also be used for possession checks.

Permissions default to scope `None`:
```bash
julia> Permission("example:resource:action")

Permission("example", ["resource"], ["action"], "", FlatRBAC.None)
```

The package provides implementation for three base scopes: 

`FlatRBAC.All - Type`

This scope acts as an `wildcard` and will, by default, grant access to any other scope

`FlatRBAC.Own - Type`

Own and Own subtypes are useful for dealing with **resource possession** and should be used in conjunction with ownership/possession checks in the application logic

`FlatRBAC.None - Type`

This is the default scope and will, by default, only grant access to the None scope

#### `AbstractScope - Type`

A `Scope` is a subtype of `AbstractScope`, which defines the following **interface methods**:

>`Base.string(::Type{<:Scope})::String`<br/>
>`Scope(::Val{:lowercasename})::Scope`<br/>
>`iswildcard(::Type{<:Scope})::Bool`<br/>

The package provides default behaviour for `AbstractScope` subtypes
```julia
abstract type MyScope <:FlatRBAC.Scope end

scoped = Permission("example:resource:read:myscope")
# Permission("example", ["resource"], ["read"], "", MyScope)
```
**Examples**
```julia
abstract type App <:MyScope end
abstract type API <:MyScope end
```
```jldoctest
julia> isauthorised(Permission(":r:crud:myscope"), Permission(":r:crud:app"), scoped=true)
true
julia> isauthorised(Permission(":r:crud:app"), Permission(":r:crud:API"), scoped=true)
false
julia> isauthorised(Permission(":r:crud:app"), Permission(":r:crud:own"), scoped=true)
true
```

### Performance considerations

Although the package provides default logic for out of the box definition and usage of custom scopes, these are not very performant.

Signigicant performance gains may be achieved by implementing `Base.string` and `Scope` methods over custom scopes.

Also note that the method `FlatRBAC.Scope(::Val{:symbol})` requires `:symbol` to be the lowercase representation of the scope string. String implementation itself may yield non lowercase letters or other characters, as show bellow:

```bash 
julia> abstract type NonPerformant <:MyScope end

julia> @time Base.string(NonPerformant)
0.000019 seconds (10 allocations: 672 bytes)
"NonPerformant"

julia> @time Permission(":::NONPerformant") # case does not matter here
  0.096760 seconds (10.80 k allocations: 8.795 MiB)
Permission("", ["*"], ["*"], "", NonPerformant)
```

```bash
julia> abstract type Performant <:MyScope end

julia> Base.string(::Type{Performant}) = "Performant"
julia> @time Base.string(Performant)
0.000001 seconds
"performant"

julia> @time Permission(":::performant") # case does not matter here
0.097665 seconds (9.80 k allocations: 7.994 MiB)
Permission("", ["*"], ["*"], "", Performant)

julia> FlatRBAC.Scope(::Val{:performant}) = Performant # :performant must be lowercase here

juli> @time Permission(":::performant")
0.000064 seconds (68 allocations: 4.609 KiB)
Permission("", ["*"], ["*"], "", Performant)
```
