# Roles

## [AbstractRole - Type](@ref)

A Role is a subtype of `AbstractRole`, which defines the following interface methods:
>`name(<:AbstractRole)::String`<br/>
>`description(<:AbstractRole)::String`<br/>
>`permissions(<:AbstractRole)::Vector{<:AbstractPermission}`<br/>
>`hash(<:AbstractRole)::UInt64`