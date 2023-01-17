# Scope 

# Performance considerations

Although the package provides default logic for out of the box definition and usage of custom scopes, these are not very performant.

Signigicant performance gains may be achieved by implementing `Base.string` and `Scope` methods over custom scopes.

Also note that the method `FlatRBAC.Scope(::Val{:symbol})` requires `:symbol` to be the lowercase representation of the scope string. String implementation itself may yield non lowercase letters or other characters, as shown bellow:

```bash 
julia> abstract type NonPerformant <:FlatRBAC.Scope end

julia> @time Base.string(NonPerformant)
0.000019 seconds (10 allocations: 672 bytes)
"NonPerformant"

julia> @time Permission(":::NONPerformant") # case does not matter here
  0.096760 seconds (10.80 k allocations: 8.795 MiB)
Permission("", ["*"], ["*"], "", NonPerformant)
```

```bash
julia> abstract type Performant <:FlatRBAC.Scope end

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
