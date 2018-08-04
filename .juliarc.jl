if VERSION ≤ v"0.6.9" && isdir(Pkg.dir("OhMyREPL"))
    @eval using OhMyREPL
end

if isdir(Pkg.dir("Revise"))
    @schedule begin
        sleep(0.1)
        @eval using Revise
    end
end

macro include(f)
    quote
        include($f)
    end
end
