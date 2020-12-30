using MultiAgentSysAdmin
using Documenter

makedocs(;
    modules=[MultiAgentSysAdmin],
    authors="rejuvyesh <mail@rejuvyesh.com> and contributors",
    repo="https://github.com/rejuvyesh/MultiAgentSysAdmin.jl/blob/{commit}{path}#L{line}",
    sitename="MultiAgentSysAdmin.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://rejuvyesh.github.io/MultiAgentSysAdmin.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/rejuvyesh/MultiAgentSysAdmin.jl",
)
