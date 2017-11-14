if VERSION ≤ v"0.6.2" && isdir(Pkg.dir("OhMyREPL"))
    @eval using OhMyREPL
end

macro include(f)
    quote
        include($f)
    end
end
