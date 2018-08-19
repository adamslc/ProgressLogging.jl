mutable struct Progress
    output::IO

    progress::Real
    
    tfirst::Float64
    tlast::Float64
    dt::Float64

    printed::Bool

    desc::AbstractString
    barlen::Int
    barglyphs::BarGlyphs
    desc_color::Symbol
    bar_color::Symbol

    float::Bool

    numprintedvalues::Int
    current_values::Vector{Any}

    function Progress(; dt=0.1, desc="Progress: ", desc_color=:green,
                            bar_color=:color_normal, output=stderr,
                            barlen=tty_width(desc), float::Bool=true,
                            barglyphs=BarGlyphs('|','█','█',' ','|'))
        progress = 0.
        tfirst = tlast = time()
        printed = false
        numprintedvalues = 0

        new(output, progress, tfirst, tlast, dt, printed, desc, barlen,
            barglyphs, desc_color, bar_color, float, numprintedvalues, Any[])
    end
end

function print_progress(p::Progress)
    t = time()

    bar = barstring(p.barlen, p.progress, barglyphs=p.barglyphs)
    elapsed_time = t - p.tfirst
    est_total_time = elapsed_time / p.progress
    if 0 <= est_total_time <= typemax(Int)
        eta_sec = round(Int, est_total_time - elapsed_time )
        eta = durationstring(eta_sec)
    else
        eta = "N/A"
    end
    bar_str = @sprintf "%3u%%%s  ETA: %s" round(Int, 100*p.progress) bar eta

    prefix = length(p.current_values) == 0 ? "[ " : "┌ "
    printover(p.output, prefix*p.desc, bar_str, p.desc_color, p.bar_color)
    printvalues!(p, p.current_values; prefix_color=p.desc_color, value_color=p.bar_color)

    # Compensate for any overhead of printing. This can be
    # especially important if you're running over a slow network
    # connection.
    p.tlast = t + 2*(time()-t)
    p.printed = true

    return nothing
end

function finish_progress(p::Progress)
    !p.printed && return

    bar = barstring(p.barlen, 1, barglyphs=p.barglyphs)
    dur = durationstring(time()-p.tfirst)
    bar_str = @sprintf "100%%%s Time: %s" bar dur
    prefix = length(p.current_values) == 0 ? "[ " : "┌ "

    p.float && move_cursor_up_while_clearing_lines(p.output, p.numprintedvalues)
    printover(p.output, prefix*p.desc, bar_str, p.desc_color, p.bar_color)
    printvalues!(p, p.current_values; prefix_color=p.desc_color, value_color=p.bar_color)
    println(p.output)
end

# Internal method to print additional values below progress bar
function printvalues!(p::Progress, showvalues; prefix_color=false, value_color=false)
    len = length(showvalues)
    len == 0 && return

    maxwidth = maximum(Int[length(string(name)) for (name, _) in showvalues])

    for (i, (name, value)) in enumerate(showvalues)
        prefix = i == len ? "\n└   " : "\n│   "
        msg = rpad(string(name) * ": ", maxwidth+2+1) * string(value)

        (prefix_color == false) ? print(p.output, prefix) : printstyled(p.output, prefix; color=prefix_color, bold=true)
        (value_color == false) ? print(p.output, msg) : printstyled(p.output, msg; color=value_color)
    end
    p.numprintedvalues = length(showvalues)
end

function check_clear_lines(p::Progress; clear_first_line=false)
    if p.printed && p.float
        move_cursor_up_while_clearing_lines(p.output, p.numprintedvalues)
        clear_first_line && print("\r\u1b[K")
    end
end

function check_float(p::Progress)
    p.float || println(p.output)
end