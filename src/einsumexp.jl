using TupleTools, Base.Cartesian

struct EinCode{ixs, iy} end
EinCode(ixs::NTuple{N, NTuple{M, T} where M},iy::NTuple{<:Any,T}) where {N, T} = EinCode{ixs, iy}()

"""
    einsumexp(::EinCode, xs, y_size)

The brute-force looping einsum.
"""
function einsumexp(::EinCode{ixs, iy},
                xs::NTuple{N, AbstractArray{<:Any,M} where M},
                y_size::Tuple) where {N,T, ixs, iy}
    TO = mapreduce(eltype, promote_type, xs)
    out = zeros(TO, y_size...)
    einsumexp!(ixs, xs, iy, out)
end

@generated function einsumexp!(::EinCode{ixs, iy},
                xs::NTuple{N, AbstractArray{<:Any,M} where M},
                y::AbstractArray{T,L}) where {N,L,T,IT <: Union{AbstractChar,Integer}, ixs, iy}
    check_tensor_order(ixs, xs)
    inner_indices, outer_indices, locs_xs, locs_y = indices_and_locs(ixs, iy)

    quote
        # find size for each leg
        size_dict = get_size_dict($((ixs..., iy)), (xs..., y))
        outer_sizes = getindex.(Ref(size_dict), $outer_indices)
        inner_sizes = getindex.(Ref(size_dict), $inner_indices)

        # cartesian indices for outer and inner legs
        outer_ci = CartesianIndices((outer_sizes...,))
        inner_ci = CartesianIndices((inner_sizes...,))

        loop!($locs_xs, xs, $locs_y, y, outer_ci, inner_ci)
    end
end

"""indiex tensors, and return the product of elements"""
@inline @generated function map_prod(::Type{T}, xs::Tuple, ind::CartesianIndex, locs_xs::NTuple{N}) where {N, T}
    quote
        p = one(T)
        @nexprs $N i -> @inbounds p *= xs[i][index_map(ind, locs_xs[i])]
    end
end

"""
loop and accumulate products to y, the CPU version.
"""
function loop!(locs_xs::NTuple{N}, xs::NTuple{N, AbstractArray}, locs_y, y::AbstractArray{T}, outer_ci::CartesianIndices, inner_ci::CartesianIndices) where {N, T}
    @simd for i in outer_ci
        @inbounds ind_y = outer_ci[i]
        iy = index_map(ind_y, locs_y)
        for ind_x in inner_ci
            ind_xy = CartesianIndex(TupleTools.vcat(ind_y.I, ind_x.I))
            @inbounds y[iy] += map_prod(T, xs, ind_xy, locs_xs)
        end
    end
    y
end

"""take an index subset from `ind`"""
index_map(ind::CartesianIndex, locs::Tuple) = CartesianIndex(TupleTools.getindices(Tuple(ind), locs))

"""get the dictionary of `index=>size`, error if there are conflicts"""
function get_size_dict(ixs::NTuple{N, NTuple{M, T} where M} where N, xs) where T
    nt = length(ixs)
    size_dict = Dict{T,Int}()
    @inbounds for i = 1:nt
        for (N, leg) in zip(size(xs[i]), ixs[i])
            if haskey(size_dict, leg)
                size_dict[leg] == N || throw(DimensionMismatch("size of index($leg) does not match."))
            else
                size_dict[leg] = N
            end
        end
    end
    return size_dict
end

# This function only checks the order of tensors.
function check_tensor_order(ixs, xs)
    xl = xs.parameters
    length(ixs) == length(xl) || throw(ArgumentError("Number of indices and tensors not the same"))
    foreach(ixs, xl) do ix, x
        length(ix) == length(x.parameters) || throw(
        ArgumentError("Indices $ix are invalid for a tensor with ndims = $(ndims(x))"))
    end
end

# get inner indices, outer indices,
# locations of input indices in total indices
# and locations of output indices in outer indices.
function indices_and_locs(ixs, iy)
    # outer legs and inner legs
    outer_indices = unique(iy)
    inner_indices = setdiff(TupleTools.vcat(ixs...), outer_indices)

    # for indexing tensors (leg binding)
    indices = (outer_indices..., inner_indices...)
    locs_xs = Tuple(Tuple(findfirst(isequal(i), indices) for i in ix) for ix in ixs)
    locs_y = Tuple(findfirst(isequal(i), outer_indices) for i in iy)
    return inner_indices, outer_indices, locs_xs, locs_y
end