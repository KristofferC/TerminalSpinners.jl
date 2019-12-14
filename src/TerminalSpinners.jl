module TerminalSpinners

export Spinner, autospin, spin!, @spin

ESC = "\e"
CSI = "\e["
DEC_RST  = "l"
DEC_SET  = "h"
DEC_TCEM = "?25"

const TTY_HIDE_CURSOR = CSI * DEC_TCEM * DEC_RST
const TTY_SHOW_CURSOR = CSI * DEC_TCEM * DEC_SET
const TTY_CLEAR_LINE = CSI * "2K"

include("spinners.jl")

mutable struct SpinnerState
    idx::Int
end

struct Spinner{IO_t <: IO}
    frames::Vector{String}
    interval::Float64 # [s]
    stream::IO_t
    msg::Union{String, Nothing}
    channel::Channel{Symbol}
    state::SpinnerState
end

function Spinner(msg::Union{String, Nothing}=nothing; format::Symbol=:classic, output=stderr)
    format = get(FORMATS, format, nothing)
    format == nothing && error("unknown format :$format")
    frames, frequency = format[:frames], format[:frequency]
    return Spinner(frames, 1/frequency, output, msg, Channel{Symbol}(1), SpinnerState(1))
end

const SPINNER_TOKEN = ":spinner"

function spin!(s::Spinner)
    s.state.idx += 1
    s.state.idx > length(s.frames) && (s.state.idx = 1)
    print(s.stream, "\r")
    v = s.frames[s.state.idx]
    if s.msg === nothing
        print(s.stream, v)
    else
        print(s.stream, replace(s.msg, SPINNER_TOKEN => v))
    end
    return
end

function _autospin(s::Spinner)
    while true
        t = @elapsed begin
            if isready(s.channel)
                should_stop = handle_command(s.channel)
                should_stop && break
            end
            spin!(s)
        end
        sleep_time = max(0, s.interval - t)
        sleep(sleep_time)
    end
end

autospin(s::Spinner) = Threads.@spawn _autospin(s)

function handle_command(c::Channel)
    while true
        command = take!(c)
        if command !== :pause && command !== :resume && command !== :stop
            error("unknown command :$command")
        end
        command == :pause && continue
        command == :resume && return false
        command == :stop && return true
    end
end

pause!(s::Spinner)  = put!(s.channel, :pause)
resume!(s::Spinner) = put!(s.channel, :resume)
stop!(s::Spinner)   = put!(s.channel, :stop)

macro spin(spinner, task)
    return quote
        t = autospin($spinner)
        try 
            return $task
        finally
            stop!($spinner)
            print($spinner.stream, TTY_SHOW_CURSOR)
            wait(t)
        end
    end
end

end # module
