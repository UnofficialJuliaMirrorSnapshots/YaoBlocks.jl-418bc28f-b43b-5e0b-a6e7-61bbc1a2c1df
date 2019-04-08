using YaoBase, YaoArrayRegister
export Measure

mutable struct Measure{N, T, K} <: PrimitiveBlock{N, T}
    locations::NTuple{K, Int}
    collapseto::Union{Int, Nothing}
    remove::Bool
    results::Vector{Int}
    function Measure{N, T}(locations::NTuple{K, Int}, collapseto, remove) where {N, K, T}
        if collapseto !== nothing && remove == true
            error("invalid keyword combination, expect collapseto or remove, got (collapseto=$collapseto, remove=true)")
        end
        new{N, T, K}(locations, collapseto, remove)
    end
end

function Measure(::Type{T}, n::Int, locs::NTuple{K, Int}; collapseto=nothing, remove=false) where {K, T}
    Measure{n, T}(locs, collapseto, remove)
end

# NOTE: make sure this won't overwrite YaoBase.measure
Measure(n::Int, locs::NTuple{K, Int}; collapseto=nothing, remove=false) where K =
    Measure(ComplexF64, n, locs; collapseto=collapseto, remove=remove)

Measure(locs::NTuple{K, Int}; collapseto=nothing, remove=false) where K = @λ(n->Measure(n, locs; collapseto=collapseto, remove=remove))
Measure(locs::Int...; collapseto=nothing, remove=false) = Measure(locs; collapseto=collapseto, remove=remove)
mat(x::Measure) = error("use BlockMap to get its matrix.")

function apply!(r::AbstractRegister, m::Measure{N, T, 0}) where {N, T}
    if m.collapseto !== nothing
        m.results = measure_collapseto!(r; config=r.collapseto)
    elseif m.remove
        m.results = measure_remove!(r)
    else
        m.results = measure!(r)
    end
    return m
end

function apply!(r::AbstractRegister, m::Measure{N, T}) where {N, T}
    if m.collapseto !== nothing
        m.results = measure_collapseto!(r, m.locations; config=m.collapseto)
    elseif m.remove
        m.results = measure_remove!(r, m.locations)
    else
        m.results = measure!(r, m.locations)
    end
    return m
end
