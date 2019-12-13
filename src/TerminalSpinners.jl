module TerminalSpinners

export Spinner, autospin, spin

ESC = "\e"
CSI = "\e["
DEC_RST  = "l"
DEC_SET  = "h"
DEC_TCEM = "?25"

const TTY_HIDE_CURSOR = CSI * DEC_TCEM * DEC_RST
const TTY_SHOW_CURSOR = CSI * DEC_TCEM * DEC_SET
const TTY_CLEAR_LINE = CSI * "2K"

include("spinners.jl")

# State in spinner or not??
mutable struct Spinner{IO_t <: IO}
    frames::Vector{String}
    interval::Int # Hz
    stream::IO_t
    idx::Int
    msg::Union{String, Nothing}
    stopped::Bool
end
function Spinner(msg::Union{String, Nothing}=nothing; format::Symbol=:classic, output=stderr)
    format = get(FORMATS, format, nothing)
    format == nothing && error("unknown format :$format")
    frames, interval = format[:frames], format[:interval]
    return Spinner(frames, interval, output, 1, msg, false)
end

stop!(s::Spinner) = (s.stopped = true)

const SPINNER_TOKEN = ":spinner"

function spin(s::Spinner)
    s.idx += 1
    s.idx > length(s.frames) && (s.idx = 1)
    print(s.stream, "\r")
    v = s.frames[s.idx]
    if s.msg === nothing
        print(s.stream, v)
    else
        print(s.stream, replace(s.msg, SPINNER_TOKEN => v))
    end
    return
end

autospin(s::Spinner) = Threads.@spawn _autospin(s)

function _autospin(s::Spinner)
    while true
        spin(s)
        s.stopped && break
        # Assume the previous commands are instant
        sleep(1 / s.interval)
    end
end

macro spin(spinner, task)
    return quote
        $(esc(spinner)).stopped=false
        t = @async autospin($(esc(spinner)))
        v = $task
        stop!($(esc(spinner)))
        wait(t)
        return v
    end
end

end # module
