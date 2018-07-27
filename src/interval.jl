export TypeSet
export LessThan, GreaterThan
export NotEqual


abstract type Interval{T} <: InfiniteSet end
Base.eltype(::Interval{T}) where {T} = T


struct TypeSet{T} <: Interval{T} end
TypeSet(T::Type) = TypeSet{T}()
Base.in(::T, ::TypeSet{T}) where {T} = true
function _intersect_to_typeset(T, U)
    V = typeintersect(T, U)
    V === Union{} && return ∅
    TypeSet{V}()
end
intersect(::TypeSet{T}, ::TypeSet{U}) where {T, U} = _intersect_to_typeset(T, U)
intersect(::TypeSet{T}, ::Interval{U}) where {T, U} = _intersect_to_typeset(T, U)
intersect(::Interval{U}, ::TypeSet{T}) where {T, U} = _intersect_to_typeset(T, U)
condition(var, ::TypeSet{T}) where {T} = "$var ∈ $(setname(T))"



struct LessThan{T} <: Interval{T}
    value::T
    inclusive::Bool
end
LessThan{T}(value) where {T} = LessThan{T}(value, false)
LessThan(value) = LessThan{typeof(value)}(value, false)
Base.convert(::Type{LessThan{T}}, s::LessThan{U}) where {U,T<:U} =
    LessThan{T}(convert(T, s.value), s.inclusive)
Base.in(x::T, s::LessThan{T}) where {T} = x < s.value || (x == s.value) & s.inclusive
function intersect(a::LessThan{T}, b::LessThan{T}) where {T}
    lt = a.value == b.value ? !a.inclusive & b.inclusive : a.value < b.value
    ifelse(lt, a, b)
end
function intersect(a::LessThan{T}, b::LessThan{U}) where {T,U}
    V = typeintersect(T, U)
    V === Union{} && return ∅
    intersect(convert(LessThan{V}, a), convert(LessThan{V}, b))
end
function condition(var, s::LessThan)
    sign = s.inclusive ? '≤' : '<'
    "$var $sign $(s.value)"
end


struct GreaterThan{T} <: Interval{T}
    value::T
    inclusive::Bool
end
GreaterThan{T}(value) where {T} = GreaterThan{T}(value, false)
GreaterThan(value) = GreaterThan{typeof(value)}(value, false)
Base.convert(::Type{GreaterThan{T}}, s::GreaterThan{U}) where {U,T<:U} =
    GreaterThan{T}(convert(T, s.value), s.inclusive)
Base.in(x::T, s::GreaterThan{T}) where {T} = x > s.value || (x == s.value) & s.inclusive
function intersect(a::GreaterThan{T}, b::GreaterThan{T}) where {T}
    gt = a.value == b.value ? !a.inclusive & b.inclusive : a.value > b.value
    ifelse(gt, a, b)
end
function intersect(a::GreaterThan{T}, b::GreaterThan{U}) where {T,U}
    V = typeintersect(T, U)
    V === Union{} && return ∅
    intersect(convert(GreaterThan{V}, a), convert(GreaterThan{V}, b))
end
function condition(var, s::GreaterThan)
    sign = s.inclusive ? '≥' : '>'
    "$var $sign $(s.value)"
end


function intersect(a::LessThan{T}, b::GreaterThan{U}) where {T, U}
    V = typeintersect(T, U)
    V == Union{} && return ∅

    a, b = convert(LessThan{V}, a), convert(GreaterThan{V}, b)

    gt = a.value == b.value ? !a.inclusive & b.inclusive : a.value < b.value
    gt && return ∅

    a.value == b.value && return (a.inclusive & b.inclusive) ? Set([a.value]) : ∅
    SetIntersection(a, b)
end
intersect(b::GreaterThan, a::LessThan) = intersect(a, b)


struct NotEqual{T} <: InfiniteSet
    values::Set{T}
    NotEqual{T}() where {T} = throw(ArgumentError("No elements provided to NotEqual; use TypeSet{$T}"))
    NotEqual{T}(xs...) where {T} = new{T}(Set{T}(xs))
end
NotEqual(xs...) = NotEqual{typejoin(typeof.(xs)...)}(xs...)
Base.:(==)(a::NotEqual, b::NotEqual) = a.values == b.values
Base.hash(s::NotEqual, h::UInt) = hash(s.values, hash(typeof(s), h))
Base.in(x::T, s::NotEqual{T}) where {T} = x ∉ s.values
intersect(a::NotEqual{T}, b::NotEqual{U}) where {T,U} = NotEqual{typejoin(T,U)}(a.values..., b.values...)
function intersect(a::NotEqual{T}, b::InfiniteSet) where {T}
    keep = Set{T}()
    for value ∈ a.values
        value ∈ b && push!(keep, value)
    end
    length(keep) == length(a.values) && return nothing
    isempty(keep) && return b
    SetIntersection(NotEqual{T}(keep...), b)
end
intersect(b::InfiniteSet, a::NotEqual) = intersect(a, b)
function condition(var, s::NotEqual)
    length(s.values) == 1 && return "$var ≠ $(first(s.values))"
    "$var ∉ {$(join(s.values, ", "))}"
end