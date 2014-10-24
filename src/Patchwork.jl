module Patchwork

using FunctionalCollections

import Base:
       convert,
       promote_rule,
       isequal,
       ==,
       >>,
       &,
       writemime

export Node,
       Elem,
       text,
       NodeVector,
       Attrs,
       attrs,
       EmptyNode,
       MaybeKey,
       tohtml,
       writemime

typealias MaybeKey Union(Nothing, Symbol)

# A Patchwork node
abstract Node

immutable Text <: Node
    text::ByteString
end
text(xs...) =
    Text(string(xs...))

convert(::Type{Node}, s::String) = text(s)
promote_rule(::Type{Node}, ::Type{String}) = Node

# Abstract out the word "Persistent"
typealias NodeVector   PersistentVector{Node}
typealias Attrs PersistentHashMap

const EmptyNode = NodeVector([])

convert(::Type{NodeVector}, x) =
    NodeVector(x)

convert{T <: Node}(::Type{NodeVector}, x::T) =
    NodeVector([x])

convert(::Type{NodeVector}, x::NodeVector) =
    x

convert(::Type{NodeVector}, x::String) =
    NodeVector([text(x)])

convert(::Type{Attrs}, x) =
    Attrs(x)

# A DOM Element
immutable Elem{ns, tag} <: Node
    count::Int
    key::MaybeKey
    attributes::Attrs
    children::NodeVector

    function Elem(key, attributes, children)
        childvec = convert(NodeVector, children)
        new(count(childvec), key,
            convert(Attrs, attributes),
            childvec)
    end
end

count(t::Text) = 1
count(el::Elem) = el.count
count(v::NodeVector) = Int[count(x) for x in v] |> sum

key(n::Elem) = n.key
key(n::Text) = nothing

# A document type
immutable DocVariant{ns}
    elements::Vector{Symbol}
end

# constructors
Elem(ns, name, attrs, children, _key::MaybeKey=nothing) =
    Elem{is(ns, None) ? ns : symbol(ns) , symbol(name)}(
        _key, attrs, children)

Elem(ns, name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Elem(ns, name, Attr[map(Attr, kwargs)...], children, _key=_key)

Elem(name, children=EmptyNode; _key::MaybeKey=nothing, kwargs...) =
    Elem(None, name, Attr[map(Attr, kwargs)...], children, _key=_key)

isequal{ns,name}(a::Elem{ns,name}, b::Elem{ns,name}) =
    a === b || (isequal(a.attributes, b.attributes) &&
                sequal(a.children, b.children))
isequal(a::Elem, b::Elem) = false

==(a::Text, b::Text) = a.text == b.text
=={ns, name}(a::Elem{ns, name}, b::Elem{ns,name}) =
    a === b || (a.attributes == b.attributes &&
                a.children == b.children)
==(a::Elem, b::Elem) = false

# Combining elements
(+)(ns::Union(Node, String)...) =
   NodeVector([convert(Node, n) for n in ns])
(+)(a::NodeVector, b::Union(Node, String)) =
   push(a, b)
(+)(a::Union(Node, String), b::NodeVector) =
   append(NodeVector([a]), b)
(+)(a::NodeVector, b::NodeVector) = append(a, b)

# Manipulating attributes
attrs(; kwargs...) = kwargs
(&){ns, name}(a::Elem{ns, name}, itr) =
    Elem{ns, name}(key(a), merge(a.attributes, itr), a.children)

include("variants.jl")
include("combinators.jl")
include("writers.jl")
include("diff.jl")

if isdefined(Main, :IJulia)
    include("ijulia.jl")
end

end # module
