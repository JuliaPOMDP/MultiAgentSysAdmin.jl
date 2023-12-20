using MultiAgentSysAdmin
using Documenter

makedocs(;
    sitename="MultiAgentSysAdmin.jl",
    authors="rejuvyesh <mail@rejuvyesh.com> and contributors",
    modules=[MultiAgentSysAdmin],
    format=Documenter.HTML()
)

deploydocs(;
    repo="github.com/JuliaPOMDP/MultiAgentSysAdmin.jl.git",
)
