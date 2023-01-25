# Permission

## [AbstractPermission - Type](@ref)

A Permission is a subtype of `AbstractPermission`, which defines the following **interface methods**:

>`name(<:AbstractPermission)::String`<br/>
>`scope(<:AbstractPermission)::Scope`<br/>
>`actions(<:AbstractPermission)::Vector{String}`<br/>
>`resources(<:AbstractPermission)::Vector{String}`<br/>
>`hash(<:AbstractPermission)::UInt64`