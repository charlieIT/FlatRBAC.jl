struct NotImplemented <:Exception 
    method
    args::Tuple
end

abstract type PermissionException <:Exception end

abstract type InvalidExpression <:Exception   end

struct InvalidPermissionExpression <:InvalidExpression
    expression::String
end
Base.showerror(io::IO, e::InvalidPermissionExpression) = print(io, "InvalidPermissionExpression: $(e.expression)")

struct InvalidGrantExpression <:InvalidExpression
    expression::String
end
Base.showerror(io::IO, e::InvalidGrantExpression) = print(io, "InvalidGrantExpression: $(e.expression)")

struct InvalidScope <:Exception
    scope::String
end
function Base.showerror(io::IO, e::InvalidScope) 
    print(io, "Unrecognized scope representation `$(e.scope)`. Maybe missing `Base.string(::Type{<:CustomScope})` implementation?")
end


abstract type Unauthorized <:Exception end