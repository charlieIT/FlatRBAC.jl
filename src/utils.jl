#= 
    Based on https://gist.github.com/tshort/3835660
=#
function _subtypes(type::Type)
    return _subtypes!(Any[], type)
end

function _subtypes!(out, type::Type)
    if !isabstracttype(type)
        push!(out, type)
    else
        foreach(T->_subtypes!(out, T), InteractiveUtils.subtypes(type))
    end
    push!(out, type)
    return unique(out)
end

function _scope_from_str(scope::String)
    match = filter(T->lowercase(string(T)) == lowercase(scope), _subtypes(Scope))
    @assert !isempty(match) throw(InvalidScope(scope))
    return first(match)
end