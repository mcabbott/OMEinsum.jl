using Test
using OMEinsum

@testset "combineops" begin
    @test_throws ArgumentError OMEinsum.combineops(OMEinsum.Diag(1), OMEinsum.Trace(2))
end

@testset "einsumopt" begin
    # matrix and vector multiplication
    a,b,c = randn(2,2), rand(2,2), rand(2,2)
    v = rand(2)
    t = randn(2,2,2,2)
    @test einsumopt(((1,2),(2,3),(3,4)), (a,b,c), (1,4)) ≈ a * b * c
    @test einsumopt(((1,20),(20,3),(3,4)), (a,b,c), (1,4)) ≈ a * b * c
    @test einsumopt(((1,2),(2,3),(3,4)), (a,b,c), (4,1)) ≈ permutedims(a*b*c, (2,1))
    @test einsumopt(((1,2),(2,)), (a,v), (1,)) ≈ a * v

    # contract to 0-dim array
    @test einsumopt(((1,2),(1,2)), (a,a), ())[] ≈ sum(a .* a)

    # trace
    @test einsumopt(((1,1),), (a,),())[] ≈ sum(a[i,i] for i in 1:2)
    aa = rand(2,4,4,2)
    @test einsumopt(((1,2,2,1),), (aa,),())[] ≈ sum(aa[i,j,j,i] for i in 1:2, j in 1:4)


    # partial trace
    @test einsumopt(((1,2,2,3),), (aa,),(1,3)) ≈ sum(aa[:,i,i,:] for i in 1:4)

    # diag
    @test einsumopt(((1,2,2,3),), (aa,), (1,2,3)) ≈ aa[:,[CartesianIndex(i,i) for i in 1:4],:]


    # permutation
    @test einsumopt(((1,2),), (a,), (2,1)) ≈ permutedims(a,(2,1))
    @test einsumopt(((1,2,3,4),), (t,),(2,3,1,4)) ≈ permutedims(t,(2,3,1,4))

    # tensor contraction
    ta = zeros(size(t)[[1,2]]...)
    for (i,j,k,l) in Iterators.product(1:2,1:2,1:2,1:2)
        ta[i,l] += t[i,j,k,l] * a[j,k]
    end
    @test einsumopt(((1,2,3,4), (2,3)), (t,a), (1,4)) ≈  ta

    ta = zeros(size(t)[[1,2]]...)
    for (i,j,k,l) in Iterators.product(1:2,1:2,1:2,1:2)
        ta[i,l] += t[l,k,j,i] * a[j,k]
    end
    @test einsumopt(((4,3,2,1), (2,3)), (t,a),(1,4)) ≈  ta

    # star-contraction
    aaa = zeros(2,2,2);
    for (i,j,k,l) in Iterators.product(1:2,1:2,1:2,1:2)
        aaa[j,k,l] += a[i,j] * a[i,k] * a[i,l]
    end
    @test aaa ≈ einsumopt(((1,2),(1,3),(1,4)), (a,a,a),(2,3,4))

    # star and contract
    aaa = zeros(2);
    for (i,j,l) in Iterators.product(1:2,1:2,1:2)
        aaa[l] += a[i,j] * a[i,j] * a[i,l]
    end
    @test einsumopt(((1,2),(1,2),(1,3)), (a,a,a), (3,)) ≈ aaa

    # index-sum
    a = rand(2,2,5)
    @test einsumopt(((1,2,3),),(a,),(1,2)) ≈ sum(a, dims=3)

    # Hadamard product
    a = rand(2,3)
    b = rand(2,3)
    @test einsumopt(((1,2),(1,2)), (a,b), (1,2)) ≈ a .* b

    # Outer
    a = rand(2,3)
    b = rand(2,3)
    @test einsumopt(((1,2),(3,4)),(a,b),(1,2,3,4)) ≈ reshape(a,2,3,1,1) .* reshape(b,1,1,2,3)

    # Projecting to diag
    a = rand(2,2)
    a2 = [a[1] 0; 0 a[4]]
    @test einsumopt(((1,1),), (a,), (1,1)) ≈ a2

    ## operations that can be combined
    a = rand(2,2,2,2)
    @test einsumopt(((1,1,2,2),), (a,), ())[] ≈ sum(a[[CartesianIndex(i,i) for i in 1:2], [CartesianIndex(i,i) for i in 1:2]])

    @test einsumopt(((1,2,3,4), (3,4,5,6)), (a,a), (1,2,5,6)) ≈ reshape(reshape(a,4,4) * reshape(a,4,4),2,2,2,2)
end