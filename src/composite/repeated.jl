using YaoBase
export RepeatedBlock, repeat

"""
    RepeatedBlock <: AbstractContainer

Repeat the same block on given locations.
"""
struct RepeatedBlock{N, C, GT <: AbstractBlock, T} <: AbstractContainer{GT, N, T}
    content::GT
    locs::NTuple{C, Int}
end

function RepeatedBlock{N}(block::AbstractBlock{M, T}, locs::NTuple{C, Int}) where {N, M, T, C}
    @assert_locs_safe N Tuple(i:i+M-1 for i in locs)
    return RepeatedBlock{N, C, typeof(block), T}(block, locs)
end

function RepeatedBlock{N}(block::GT) where {N, M, T, GT <: AbstractBlock{M, T}}
    return RepeatedBlock{N, N, GT, T}(block, Tuple(1:M:N-M+1))
end

"""
    repeat(n, x::AbstractBlock[, locs]) -> RepeatedBlock{n}

Create a [`RepeatedBlock`](@ref) with total number of qubits `n` and the block
to repeat on given location or on all the locations.

# Example

This will create a repeat block which puts 4 X gates on each location.

```jldoctest
julia> repeat(4, X)
nqubits: 4, datatype: Complex{Float64}
repeat on (1, 2, 3, 4)
└─ X gate
```

You can also specify the location

```jldoctest
julia> repeat(4, X, (1, 2))
nqubits: 4, datatype: Complex{Float64}
repeat on (1, 2)
└─ X gate
```

But repeat won't copy the gate, thus, if it is a gate with parameter, e.g a `phase(0.1)`, the parameter
will change simultaneously.

```jldoctest
julia> g = repeat(4, phase(0.1))
nqubits: 4, datatype: Complex{Float64}
repeat on (1, 2, 3, 4)
└─ phase(0.1)

julia> g.content
phase(0.1)

julia> g.content.theta = 0.2
0.2

julia> g
nqubits: 4, datatype: Complex{Float64}
repeat on (1, 2, 3, 4)
└─ phase(0.2)
```
"""
Base.repeat(n::Int, x::AbstractBlock, locs::Int...) =
    repeat(n, x, locs)
Base.repeat(n::Int, x::AbstractBlock, locs::NTuple{C, Int}) where C =
    RepeatedBlock{n}(x, locs)
Base.repeat(n::Int, x::AbstractBlock, locs) = repeat(n, x, locs...)
Base.repeat(n::Int, x::AbstractBlock) = RepeatedBlock{n}(x)
Base.repeat(x::AbstractBlock) = @λ(n->repeat(n, x))

"""
    repeat(x::AbstractBlock, locs)

Lazy curried version of [`repeat`](@ref).
"""
Base.repeat(x::AbstractBlock, locs) = @λ(n->repeat(n, x, locs...,))

occupied_locs(x::RepeatedBlock) = Iterators.flatten(k:k+nqubits(x.content)-1 for k in x.locs)
chsubblocks(x::RepeatedBlock{N}, blk::AbstractBlock) where N = RepeatedBlock{N}(blk, x.locs)
PreserveProperty(x::RepeatedBlock) = PreserveAll()

mat(rb::RepeatedBlock{N}) where N = hilbertkron(N, fill(mat(rb.content), length(rb.locs)), [rb.locs...])
mat(rb::RepeatedBlock{N, 0, GT, T}) where {N, GT, T} = IMatrix{1<<N, T}()

function apply!(r::AbstractRegister, rp::RepeatedBlock)
    _check_size(r, rp)
    m  = mat(rp.content)
    for addr in rp.locs
        instruct!(matvec(r.state), m, Tuple(addr:addr+nqubits(rp.content)-1))
    end
    return r
end

# specialization
for G in [:X, :Y, :Z, :S, :T, :Sdag, :Tdag]
    GT = Expr(:(.), :ConstGate, QuoteNode(Symbol(G, :Gate)))
    @eval function apply!(r::AbstractRegister, rp::RepeatedBlock{N, C, <:$GT}) where {N, C}
        for addr in rp.locs
            instruct!(matvec(r.state), Val($(QuoteNode(G))), Tuple(addr:addr+nqubits(rp.content)-1))
        end
        return r
    end
end

apply!(reg::AbstractRegister, rp::RepeatedBlock{N, 0}) where N = reg

cache_key(rb::RepeatedBlock) = (rb.locs, cache_key(rb.content))

Base.adjoint(blk::RepeatedBlock{N}) where N = RepeatedBlock{N}(adjoint(blk.content), blk.locs)
Base.copy(x::RepeatedBlock{N}) where N = RepeatedBlock{N}(x.content, x.locs)
Base.:(==)(A::RepeatedBlock, B::RepeatedBlock) = A.locs == B.locs && A.content == B.content

function YaoBase.iscommute(x::RepeatedBlock{N}, y::RepeatedBlock{N}) where N
    if x.locs == y.locs
        return iscommute(x.content, y.content)
    else
        iscommute_fallback(x, y)
    end
end
