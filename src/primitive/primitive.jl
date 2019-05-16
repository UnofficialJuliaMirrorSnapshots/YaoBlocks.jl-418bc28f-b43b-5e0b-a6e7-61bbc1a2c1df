export PrimitiveBlock

"""
    PrimitiveBlock{N} <: AbstractBlock{N}

Abstract type that all primitive block will subtype from. A primitive block
is a concrete block who can not be decomposed into other blocks. All composite
block can be decomposed into several primitive blocks.

!!! note

    subtype for primitive block with parameter should implement `hash` and `==`
    method to enable key value cache.
"""
abstract type PrimitiveBlock{N} <: AbstractBlock{N} end

# NOTE: we cannot change subblocks of a primitive block
#      since they are primitive, therefore we return themselves
chsubblocks(x::PrimitiveBlock, it) = x
subblocks(x::PrimitiveBlock) = ()
# NOTE: all primitive block should name with postfix Gate
#       and each primitive block should stay in a single
#       file whose name is in lowercase and underscore.
include("const_gate.jl")
include("phase_gate.jl")
include("shift_gate.jl")
include("rotation_gate.jl")
include("swap_gate.jl")
include("time_evolution.jl")
include("reflect_gate.jl")
include("general_matrix_gate.jl")
include("math_gate.jl")
include("measure.jl")
