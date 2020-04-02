module RocketEnumerateOperatorTest

using Test
using Rocket

include("./test_helpers.jl")

@testset "operator: enumerate()" begin

    run_testset([
        (
            source      = from([ 3, 2, 1 ]) |> enumerate(),
            values      = @ts([ (3, 1), (2, 2), (1, 3) ] ~ c),
            source_type = Tuple{Int, Int}
        ),
        (
            source      = completed(Int) |> enumerate(),
            values      = @ts(c),
            source_type = Tuple{Int, Int}
        ),
        (
            source      = throwError("e", Float64) |> enumerate(),
            values      = @ts(e("e")),
            source_type = Tuple{Float64, Int}
        ),
        (
            source      = never(String) |> enumerate(),
            values      = @ts(),
            source_type = Tuple{String, Int}
        )
    ])

end

end
