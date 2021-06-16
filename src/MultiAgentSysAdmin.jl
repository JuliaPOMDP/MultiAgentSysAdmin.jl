module MultiAgentSysAdmin

# Write your package code here.
using StaticArrays
using LightGraphs
using POMDPs
using Random

using MultiAgentPOMDPs
using POMDPModelTools: Deterministic

const MAPOMDPs = MultiAgentPOMDPs

"""
- `status`: {good, faulty, dead}
- `load`: {idle, loaded, success}
"""
const MachineState = SVector{2, Int}
const MachineAction = @SArray [0, 1] # noop, reboot

"""
- `p_fail_base`:
- `p_fail_bonus`:
- `p_dead_base`:
- `p_dead_bonus`:
- `p_load`:  probability of getting a job when idle.
- `p_doneG`: probability of completing a job when good.
- `p_doneF`: probability of completing a job when faulty.
`p_fail_bonus` and `p_dead_bonus` are additional bonuses counted
when all neighbors are faulty. Counted per agent.
If a machine with 2 neighbors has a single faulty neighbor, it will get
an additional failing probability of `p_fail_bonus/2`. If the same machine
has one faulty neighbor and one dead neighbor, it will get a penalty of
`p_fail_bonus/2 + p_dead_bonus/2`.
"""
abstract type AbstractSysAdmin{Bool} <: JointMDP{Vector{MachineState}, Vector{Int}} end

Base.@kwdef struct UniSysAdmin{T} <: AbstractSysAdmin{T}
    nagents::Int = 4
    # status
    p_fail_base::Float64 = 0.4
    p_fail_bonus::Float64 = 0.2
    p_dead_base::Float64 = 0.1
    p_dead_bonus::Float64 = 0.5
    # load
    p_load::Float64 = 0.6
    p_doneG::Float64 = 0.9
    p_doneF::Float64 = 0.6

    discount::Float64 = 0.9
    reboot_penalty = -0.7
end

Base.@kwdef struct BiSysAdmin{T} <: AbstractSysAdmin{T}
    nagents::Int = 4
    # status
    p_fail_base::Float64 = 0.4
    p_fail_bonus::Float64 = 0.2
    p_dead_base::Float64 = 0.1
    p_dead_bonus::Float64 = 0.5
    # load
    p_load::Float64 = 0.6
    p_doneG::Float64 = 0.9
    p_doneF::Float64 = 0.6

    discount::Float64 = 0.9
    reboot_penalty = -0.0
end

Base.@kwdef struct RingofRingSysAdmin{T} <: AbstractSysAdmin{T}
    nrings::Int = 3
    nagents_per_ring::Int = 3
    # status
    p_fail_base::Float64 = 0.4
    p_fail_bonus::Float64 = 0.2
    p_dead_base::Float64 = 0.1
    p_dead_bonus::Float64 = 0.5
    # load
    p_load::Float64 = 0.6
    p_doneG::Float64 = 0.9
    p_doneF::Float64 = 0.6

    discount::Float64 = 0.9
    reboot_penalty = -0.0
end

Base.@kwdef struct StarSysAdmin{T} <: AbstractSysAdmin{T}
    nagents::Int = 4
    # status
    p_fail_base::Float64 = 0.4
    p_fail_bonus::Float64 = 0.2
    p_dead_base::Float64 = 0.1
    p_dead_bonus::Float64 = 0.5
    # load
    p_load::Float64 = 0.6
    p_doneG::Float64 = 0.9
    p_doneF::Float64 = 0.6

    discount::Float64 = 0.9
    reboot_penalty = -0.0
end

Base.@kwdef struct RandomSysAdmin{T} <: AbstractSysAdmin{T}
    nagents::Int = 4
    nedges::Int = 5
    seed::Int = 1
    # status
    p_fail_base::Float64 = 0.4
    p_fail_bonus::Float64 = 0.2
    p_dead_base::Float64 = 0.1
    p_dead_bonus::Float64 = 0.5
    # load
    p_load::Float64 = 0.6
    p_doneG::Float64 = 0.9
    p_doneF::Float64 = 0.6

    discount::Float64 = 0.9
    reboot_penalty = -0.0
end


POMDPs.discount(p::AbstractSysAdmin) = p.discount
#POMDPs.isterminal(p::AbstractSysAdmin, s) = all(x->x[2] == 3) # XXX
POMDPs.isterminal(p::AbstractSysAdmin, s) = false

POMDPs.actionindex(p::AbstractSysAdmin, a, c) = findfirst(isequal(a), MachineAction)

MAPOMDPs.n_agents(p::AbstractSysAdmin) = p.nagents
MAPOMDPs.n_agents(p::RingofRingSysAdmin) = p.nagents_per_ring * p.nrings

MAPOMDPs.agent_actions(p::AbstractSysAdmin, idx::Int64, s::MachineState) = MachineAction
MAPOMDPs.agent_actions(p::AbstractSysAdmin, idx::Int64) = MachineAction
MAPOMDPs.agent_actionindex(p::AbstractSysAdmin, idx::Int64, a) = findfirst(isequal(a), MAPOMDPs.agent_actions(p, idx))
POMDPs.actions(p::AbstractSysAdmin) = vec(map(collect, Iterators.product((MAPOMDPs.agent_actions(p, i) for i in 1:MAPOMDPs.n_agents(p))...)))
POMDPs.actionindex(p::AbstractSysAdmin, a) = findfirst(isequal(a), POMDPs.actions(p))

function coord_graph_adj_mat(p::UniSysAdmin)
    mat = zeros(Int64, p.nagents, p.nagents)
    for i in 1:p.nagents-1
        mat[i, i+1] = 1
    end
    mat[p.nagents, 1] = 1
    return mat
end

function coord_graph_adj_mat(p::BiSysAdmin)
    mat = zeros(Int64, p.nagents, p.nagents)
    for i in 1:p.nagents-1
        mat[i, i+1] = 1
    end
    mat[p.nagents, 1] = 1
    mat = mat + mat'
    return mat
end

function coord_graph_adj_mat(p::RingofRingSysAdmin)
    na = MAPOMDPs.n_agents(p)
    mat = zeros(Int64, na, na)
    # Inner ring
    for idx in Iterators.product(1:p.nrings:na, 1:p.nrings:na)
        if idx[1] == idx[2]
            continue
        end
        mat[idx...] = 1
    end
    # rings on inner ring
    for i in 1:p.nrings:na-1
        for j in i:(i+p.nagents_per_ring-2)
            mat[j, j+1] = 1
            mat[j+1, j] = 1
        end
        mat[i, i+p.nagents_per_ring-1] = 1
        mat[i+p.nagents_per_ring-1, i] = 1
    end
    return mat
end


function coord_graph_adj_mat(p::RandomSysAdmin)
    return Matrix(adjacency_matrix(coordination_graph(p)))
end

function MAPOMDPs.coordination_graph(p::UniSysAdmin)
    DiGraph(coord_graph_adj_mat(p))
end

function MAPOMDPs.coordination_graph(p::BiSysAdmin)
    SimpleGraph(coord_graph_adj_mat(p))
end

function MAPOMDPs.coordination_graph(p::RandomSysAdmin)
    SimpleGraph{Int}(p.nagents, p.nedges, seed=p.seed)
end

function MAPOMDPs.coordination_graph(p::RingofRingSysAdmin)
    SimpleGraph(coord_graph_adj_mat(p))
end

function coord_graph_adj_mat(p::StarSysAdmin)
    mat = zeros(Int64, p.nagents, p.nagents)
    for i in 2:p.nagents
        mat[1, i] = 1
        mat[i, 1] = 1
    end
    return mat
end

function MAPOMDPs.coordination_graph(p::StarSysAdmin)
    SimpleGraph(coord_graph_adj_mat(p))
end

# status: good, fail, dead
# load: idle, work, done
MAPOMDPs.agent_states(p::AbstractSysAdmin, idx::Int64) = vec(MachineState[MachineState(status,load) for status in 1:3, load in 1:3])
MAPOMDPs.agent_stateindex(p::AbstractSysAdmin, idx::Int64, s) = findfirst(isequal(s), MAPODMPs.agent_states(p, idx))
POMDPs.states(p::AbstractSysAdmin) = vec(map(collect, Iterators.product((MAPOMDPs.agent_states(p, i) for i in 1:MAPOMDPs.n_agents(p))...)))
POMDPs.stateindex(p::AbstractSysAdmin, s) = findfirst(isequal(s), POMDPs.states(p))

function POMDPs.initialstate(p::AbstractSysAdmin)
    return Deterministic(MachineState[MachineState(1, 1) for _ in 1:MAPOMDPs.n_agents(p)])
end

function sysadmin_loop(p, s, a, rng)
    coordgraph = MAPOMDPs.coordination_graph(p) #SimpleGraph(coord_graph_adj_mat(p))
    sp_vec = Vector{MachineState}(undef, MAPOMDPs.n_agents(p))
    r_vec = Vector{Float64}(undef, MAPOMDPs.n_agents(p))
    for aidx in 1:MAPOMDPs.n_agents(p)
        rew = 0.0
        bonus = 0.0
        neighs = neighbors(coordgraph, aidx)
        for neigh in neighs
            status = s[neigh][1]
            if status == 2  # neighbor Fail
                bonus += p.p_fail_bonus
            elseif status == 3 # neighbor dead
                bonus += p.p_dead_bonus
            end
        end
        bonus /= length(neighs)
        p_fail = p.p_fail_base + bonus
        p_dead = p.p_dead_base + bonus

        # Rewards only if noop
        if a[aidx] == 0         # noop
            status = s[aidx][1]
            if status == 1      # Good
                if rand(rng) < p_fail
                    newstatus = 2
                else
                    newstatus = 1
                end
            elseif status == 2
                if rand(rng) < p_dead
                    newstatus = 3
                else
                    newstatus = 2
                end
            elseif status == 3
                newstatus = 3
            end

            load = s[aidx][1]
            if load == 1        # idle
                if newstatus == 1
                    if rand(rng) < p.p_load
                        newload = 2
                    else
                        newload = 1
                    end
                elseif newstatus == 2
                    if rand(rng) < p.p_load
                        newload = 2
                    else
                        newload = 1
                    end
                elseif newstatus == 3
                    newload = 1
                end
            elseif load == 2    # work
                if newstatus == 1
                    if rand(rng) < p.p_doneG
                        newload = 3
                        rew = 1.0 # finish reward
                    else
                        newload = 2
                    end
                elseif newstatus == 2
                    if rand(rng) < p.p_doneF
                        newload = 3
                        rew = 1.0 # finish reward
                    else
                        newload = 2
                    end
                elseif newstatus == 3 # dead
                    newload = 1
                end
            elseif load == 3    # done
                newload = 3
            end
        else                    # reboot
            newstatus = 1       # Good
            newload = 1
            rew += p.reboot_penalty
        end
        sp_vec[aidx] = MachineState(newstatus, newload)
        r_vec[aidx] = rew
    end
    return (sp=sp_vec, r=r_vec)
end

"""
Basically, the only way we can get reward is by:
- Starting from the Load state (since it's the only one that can complete)
- Doing action 0;
- And ending up in the Done state.
dead machine increases the probability that its neighbors become faulty and die
system receives a reward of 1 if a process terminates successfully
status is faulty, processes take longer to terminate
If the machine dies, the process is lost.
"""
function POMDPs.gen(p::AbstractSysAdmin{false}, s, a, rng)
    return sysadmin_loop(p, s, a, rng)    
end

function POMDPs.gen(p::AbstractSysAdmin{true}, s, a, rng)
    sp_vec, r_vec = sysadmin_loop(p, s, a, rng)
    return (sp=sp_vec, r=sum(r_vec))
end

export UniSysAdmin, BiSysAdmin, RingofRingSysAdmin, RandomSysAdmin

end
