using Random
using Test

using MultiAgentPOMDPs
using MultiAgentSysAdmin
using POMDPs


@testset "MultiAgentSysAdmin.jl" begin
    # Write your tests here.
    for sysfn in [UniSysAdmin, BiSysAdmin, RingofRingSysAdmin, RandomSysAdmin]
        for g in (true, false)
            sys = sysfn{g}()

            @test sys isa sysfn
            s = rand(initialstate(sys))
            a = ones(Int, n_agents(sys))
            @inferred @gen(:sp, :r)(sys, s, a, MersenneTwister(42))
        end
    end 
end
