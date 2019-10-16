export apply_back!, apply_back

const Rotor{N, T} = Union{RotationGate{N, T}, PutBlock{N, <:Any, <:RotationGate{<:Any, T}}}

as_scalar(arr::AbstractArray{T,0}) where T = arr[]
as_scalar(arr) = arr

"""
    generator(rot::Rotor) -> AbstractBlock

Return the generator of rotation block.
"""
generator(rot::RotationGate) = rot.block
generator(rot::PutBlock{N, C, GT}) where {N, C, GT<:RotationGate} = PutBlock{N}(generator(rot|>content), rot |> occupied_locs)

"""
    apply_back!((ψ, ∂L/∂ψ*), circuit::AbstractBlock, collector) -> AbstractRegister

back propagate and calculate the gradient ∂L/∂θ = 2*Re(∂L/∂ψ*⋅∂ψ*/∂θ), given ∂L/∂ψ*.
`ψ` is the output register, ∂L/∂ψ* should also be register type.

Note: gradients are stored in `Diff` blocks, it can be access by either `diffblock.grad` or `gradient(circuit)`.
Note2: now `apply_back!` returns the inversed gradient!
"""
function apply_back!(st, block::AbstractBlock, collector) #,AbstractContainer{<:PrimitiveBlock}
    out, outδ = st
    if nparameters(block) == 0
        adjblock = block'
        in = apply!(out, adjblock)
        inδ = apply!(outδ, adjblock)
        return (in, inδ)
    else
        throw(MethodError(apply_back, (st, block, collector)))
    end
end

function apply_back!(st, block::Concentrator{N}, collector) where N
    out, outδ = st
    focus!(out, block.locs)
    focus!(outδ, block.locs)
    apply_back!((out, outδ), content(block), collector)
    relax!(out, block.locs; to_nactive=N)
    relax!(outδ, block.locs; to_nactive=N)
    return (out, outδ)
end

function apply_back!(st, block::Rotor{N}, collector) where N
    out, outδ = st
    adjblock = block'
    backward_params!((out, outδ), block, collector)
    in = apply!(out, adjblock)
    inδ = apply!(outδ, adjblock)
    return (in, inδ)
end

function apply_back!(st, block::TimeEvolution{N}, collector) where N
    out, outδ = st
    adjblock = block'

    out, outδ = st
    input = apply!(out, adjblock)
    for o in outδ
        !all(x->x≈0.0im, o.state) && apply!(o, adjblock)
    end
    pushfirst!(collector, -sum(imag(input' * apply!(copy(outδ), block.H))))
    return (input, outδ)
end

function apply_back!(st, block::PutBlock{N}, collector) where N
    out, outδ = st
    adjblock = block'
    in = apply!(out, adjblock)
    adjmat = outerprod(in, outδ)
    mat_back!(datatype(in), block, adjmat, collector)
    inδ = apply!(outδ, adjblock)
    return (in, inδ)
end

function apply_back!(st, block::KronBlock{N}, collector) where N
    apply_back!(st, chain(N, [put(loc=>block[loc]) for loc in block.locs]), collector)
end

function apply_back!(st, block::ControlBlock{N}, collector) where N
    out, outδ = st
    adjblock = block'
    in = apply!(out, adjblock)
    #adjm = adjcunmat(outerprod(in, outδ), N, block.ctrl_locs, block.ctrl_config, mat(content(block)), block.locs)
    adjmat = outerprod(in, outδ)
    mat_back!(datatype(in),block,adjmat,collector)
    inδ = apply!(outδ, adjblock)
    return (in, inδ)
end

function apply_back!(st, block::Daggered, collector)
    out, outδ = st
    adjblock = block'
    in = apply!(out, adjblock)
    adjmat = outerprod(outδ, in)
    mat_back!(datatype(in), content(block),adjmat,collector)
    inδ = apply!(outδ, adjblock)
    return (in, inδ)
end

function apply_back!(st, block::Scale, collector)
    out, outδ = st
    apply_back!((out, outδ), content(block), collector)
    outδ.state .= outδ.state .* conj(factor(block))
    out.state .= out.state ./ factor(block)
    return (out, outδ)
end

function apply_back!(st, circuit::ChainBlock, collector)
    for blk in Base.Iterators.reverse(subblocks(circuit))
        st = apply_back!(st, blk, collector)
    end
    return st
end

function apply_back!(st, circuit::Add, collector; in)
    out, outδ = st
    adjmat = outerprod(outδ, in)
    for blk in Base.Iterators.reverse(subblocks(circuit))
        mat_back!(datatype(in), blk, adjmat, collector)
    end
    inδ = apply!(outδ, adjblock)
    (in, inδ)
end

function apply_back!(st, block::RepeatedBlock{N,C}, collector) where {N,C}
    if nparameters(content(block)) == 0
        return apply!.(st, Ref(block'))
    end
    res = Any[]
    st = apply_back!(st, chain(N, [put(loc=>content(block)) for loc in block.locs]), res)
    res = dropdims(sum(reshape(res, :,C), dims=2), dims=2) |> as_scalar
    prepend!(collector, res)
    return st
end

# TODO: concentrator, repeat, kron
apply_back!(st, block::Measure, collector) = throw(MethodError(apply_back!, (st, block, collector)))

function backward_params!(st, block::Rotor, collector)
    in, outδ = st
    Σ = generator(block)
    g = dropdims(sum(conj.(state(in |> Σ)) .* state(outδ), dims=(1,2)), dims=(1,2)) |> as_scalar
    pushfirst!(collector, -imag(g)/2)
    in |> Σ
    nothing
end

"""
    apply_back(st::Tuple{<:ArrayReg, <:ArrayReg}, block::AbstractBlock; kwargs...) -> (out, outδ), paramsδ

The backward function of `apply!`. Returns a tuple of ((input register, gradient of input register), parameter gradients)
"""
function apply_back(st::Tuple{<:ArrayReg, <:ArrayReg}, block::AbstractBlock; kwargs...)
    col=[]
    in, inδ = apply_back!(st,block,col; kwargs...)
    (in, inδ), col
end

Base.adjoint(::typeof(expect)) = Adjoint(expect)
Base.show(io::IO, ::Adjoint{Any,typeof(expect)}) = print(io, "expect'")
Base.show(io::IO, ::MIME"text/plain", ::Adjoint{Any,typeof(expect)}) = print(io, "expect'")
"""
expect')(op::AbstractBlock, circuit::Pair{<:ArrayReg, <:AbstractBlock})

"""
function (::Adjoint{Any,typeof(expect)})(op::AbstractBlock, circuit::Pair{<:ArrayReg, <:AbstractBlock})
    reg, c = circuit
    out = copy(reg) |> c
    outδ = copy(out) |> op
    (in, inδ), paramsδ = apply_back((out, outδ), c)
    return outδ => paramsδ.*2
end
