### Subject
--------------------

An automated agent, person or any relevant third party for which authorisation should be enforced.

#### Interface methods

A Subject is a subtype of `AbstractSubject`, which defines the following **interface methods**:
- `name(<:AbstractSubject)::String`
- `id(<:AbstractSubject)::String`
- `roles(<:AbstractSubject)::Vector{<:AbstractRole}`
-  `hash(<:AbstractSubject)::UInt64`

#### Usage API 

- `id(user::Subject)`
- `roles(user::Subject)`
- `name(user::Subject)`
- `permissions(user::Subject; shorthand::Bool=false)`

**grant!**
- `grant!(user::Subject, role::AbstractRole)`

**revoke!**
- `revoke!(user::Subject, role::AbstractRole)`

**authorisation**
- `isauthorised(subject::AbstractSubject, permission::AbstractPermission; singlerole::Bool=false, kwargs...)::Bool`
- `isauthorised(subject::AbstractSubject, permission_str::String; kwargs...)`