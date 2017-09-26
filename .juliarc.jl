if VERSION ≤ v"0.6" && isdir(Pkg.dir("OhMyREPL"))
    @eval using OhMyREPL
end
