struct NotImplemented <:Exception 
    method
    args::Tuple
end

abstract type PermissionException end

struct InvalidPermissionExpression <:Exception
    expression::String
end
Base.showerror(io::IO, e::InvalidPermissionExpression) = print(io, "InvalidPermissionExpression: $(e.expression)")

struct InvalidScope <:Exception
    scope::String
end
function Base.showerror(io::IO, e::InvalidScope) 
    print(io, "Unrecognized scope representation `$(e.scope)`. Maybe missing `Base.string(::Type{<:CustomScope})` implementation?")
end


abstract type Unauthorized <:Exception end

