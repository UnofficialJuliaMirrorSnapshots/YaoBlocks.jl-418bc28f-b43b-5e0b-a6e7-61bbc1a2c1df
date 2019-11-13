using Test, YaoBlocks, YaoArrayRegister
using YaoBlocks.ConstGate
using StatsBase: mean
using LinearAlgebra: tr

@testset "blockfilter expect" begin
    ghz = (ArrayReg(bit"0000") + ArrayReg(bit"1111")) |> normalize!
    obs1 = kron(4, 2 => Z)
    obs2 = kron(4, 2 => X)
    obs3 = repeat(4, X)
    @test expect(obs1, ghz) ≈ 0
    @test expect(obs2, ghz) ≈ 0
    @test expect(obs3, ghz) ≈ 1

    @test expect(obs3, zero_state(4) => kron(H, H, H, H)) ≈ expect(
        obs3,
        zero_state(4) |> kron(H, H, H, H),
    )
    @test expect(obs1 + obs2 + obs3, ghz) ≈ 1
    @test expect(obs1 + obs2 + obs3, repeat(ghz, 3)) ≈ [1, 1, 1]
    @test expect(2 * obs3, ghz) ≈ 2
    @test expect(2 * obs3, repeat(ghz, 3)) ≈ [2, 2, 2]

    @test blockfilter(
        ishermitian,
        chain(2, kron(2, X, P0), repeat(2, Rx(0), (1, 2)), kron(2, 2 => Rz(0.3))),
    ) == Any[X, P0, kron(2, X, P0), Rx(0), repeat(2, Rx(0), (1, 2))]
    @test blockfilter(
        b -> ishermitian(b) && b isa PrimitiveBlock,
        chain(2, kron(2, X, P0), repeat(2, Rx(0), (1, 2)), kron(2, 2 => Rz(0.3))),
    ) == [X, P0, Rx(0)]
end

@testset "density matrix" begin
    reg = rand_state(4)
    dm = reg |> density_matrix
    op = put(4, 3 => X)
    @test expect(op, dm) ≈ expect(op, reg)

    reg = rand_state(4; nbatch = 3)
    dm = reg |> density_matrix
    op = put(4, 3 => X)
    @test expect(op, dm) ≈ expect(op, reg)
end

@testset "insert_qubits!" begin
    reg = rand_state(5; nbatch = 10)
    insert_qubits!(reg, 3; nqubits = 2)
    @test reg |> nqubits == 7
    @test expect(put(7, 3 => Z), reg) .|> tr |> mean ≈ 1
    @test expect(put(7, 4 => Z), reg) .|> tr |> mean ≈ 1
end

@testset "expect" begin
    reg = rand_state(3, nbatch = 10)
    e1 = expect(put(2, 2 => X), reg |> copy |> focus!(1, 2) |> ρ)
    e2 = expect(put(2, 2 => X), reg |> copy |> focus!(1, 2))
    e3 = expect(put(3, 2 => X), reg |> ρ)
    e4 = expect(put(3, 2 => X), reg)
    e5 = expect(put(3, 2 => -X), reg)
    @test e1 ≈ e2
    @test e1 ≈ e3
    @test e1 ≈ e4
    @test e5 ≈ -e4
end

@testset "viewbatch apply" begin
    reg = zero_state(1, nbatch = 2)
    viewbatch(reg, 1) |> X
    @test reg.state[:, 1] == [0, 1]
    @test reg.state[:, 2] == [1, 0]
end
