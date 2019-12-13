using TerminalSpinners
using Documenter

makedocs(;
    modules=[TerminalSpinners],
    authors="KristofferC <kcarlsson89@gmail.com>",
    repo="https://github.com/KristofferC/TerminalSpinners.jl/blob/{commit}{path}#L{line}",
    sitename="TerminalSpinners.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://KristofferC.github.io/TerminalSpinners.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/KristofferC/TerminalSpinners.jl",
)
