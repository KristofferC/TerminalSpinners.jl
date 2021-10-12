module TerminalSpinners

using Printf

export Spinner, autospin, spin!, @spin

using Crayons

include("AnsiCodes.jl")
#=
     (minutes, seconds) = fldmod(elapsed, 60)
        (hours, minutes) = fldmod(minutes, 60)
        if hours == 0
            printstyled(s.stream, @sprintf("[%02d:%02d]", minutes, seconds); color=Base.info_color())
        else
            printstyled(s.stream, @sprintf("[%02d:%02d:%02d]", hours, minutes, seconds); color=Base.info_color())
        end
=#

ESC = "\e"
CSI = "\e["
DEC_RST  = "l"
DEC_SET  = "h"
DEC_TCEM = "?25"

function remove_ansi_characters(str::String)
    r = r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"
    return replace(str, r => "")
end



const TTY_HIDE_CURSOR = CSI * DEC_TCEM * DEC_RST
const TTY_SHOW_CURSOR = CSI * DEC_TCEM * DEC_SET
const TTY_CLEAR_LINE = CSI * "2K"

include("spinners.jl")

tostring(msg) = msg
tostring(f::Function) = f()



Base.@kwdef mutable struct Spinner{IO_t <: IO}
    frames::Vector{String} = FORMATS[:dots][:frames]
    freq::Float64 = 10.0 # [1/s]
    msg::Any = ""
    stream::IO_t = stderr   
    timer::Union{Nothing, Timer} = nothing
    hidecursor::Bool = true
    silent::Bool=false
    enabled::Bool= silent ? false : stream isa Base.TTY && !haskey(ENV, "CI")
    frame_idx::Int=1
    indent::Int=0
    color::Union{Crayon, Symbol} = Base.info_color()
end

getframe(s::Spinner) = s.frames[s.frame_idx]

function advance_frame!(s::Spinner)
    frame = s.frames[s.frame_idx]
    s.frame_idx = s.frame_idx == length(s.frames) ? 1 : s.frame_idx + 1
    return frame
end

function erase_and_reset(io::IO)
    AnsiCodes.erase_line!(io)
    AnsiCodes.cursor_horizontal_absolute!(io, 1)
end

function print_spinner(s::Spinner, io::IO)
    color = s.color
    if color isa Symbol
        printstyled(io, getframe(io); color=color)
    else
        print(io, color(getframe(io)))
    end
end

function next_line!(s::Spinner)
    return sprint(; context=s.stream) do io
        erase_and_reset(io)
        print(io, " "^s.indent)
        printstyled(io, getframe(s))
        msg = tostring(s.msg)
        print(io, " ", msg)
    end
end

function render!(s::Spinner)
    s.silent && return
    print(s.stream, next_line!(s))
    advance_frame!(s)
end

function start!(s::Spinner)
    s.silent && return
    
    if !s.enabled
        println(s.stream, s.msg)
        return
    end

    s.hidecursor && print(s.stream, TTY_HIDE_CURSOR)

    t = Timer(0.0; interval=1/s.freq) do timer
        try
            render!(s)
        catch e
            close(timer)
            @show e
        end
    end
    s.timer = t
    return s
end

function stop!(s::Spinner)
    if s.timer !== nothing
        close(s.timer)
    end
    s.frame_idx = 1
    if !s.enabled || s.silent 
        return
    end
    s.hidecursor && print(s.stream, TTY_SHOW_CURSOR)
end

function success!(s)
    stop!(s)
    return sprint(; context=s.stream) do io
        erase_and_reset(io)
        print(io, " "^s.indent)
        print(tostring(s.success))
        msg = tostring(s.msg)
        print(io, " ", msg)
    end
    stop!(s)
    print(s.stream, tostring(msg))
end

macro spin(s, work)
    return quote
        spin(() -> $(esc(work)), $(esc(s)))
    end
end

function spin(f, s::Spinner)
    start!(s)
    try
        v = f()
        success!(s)
        v
    catch
        fail!(s)
        rethrow()
    end
end


end # module
