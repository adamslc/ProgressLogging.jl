mutable struct Progress 
    progress::Float64
    
    tfirst::Float64
    tlast::Float64
    dt::Float64

    desc::AbstractString
    barlen::Int
    barglyphs::BarGlyphs
    desc_color::Symbol
    bar_color::Symbol

    numprintedvalues::Int
    current_values::Vector{Any}

    function Progress(desc="Progress: "; _dt=0.1, _desc_color=:green,
                            _bar_color=:color_normal,
                            _barlen=tty_width(desc),
                            _barglyphs=BarGlyphs('|','█','█',' ','|'),
                            _kwargs...)
        progress = 0.
        tfirst = tlast = time()
        numprintedvalues = 0

        new(progress, tfirst, tlast, _dt, desc, _barlen,
            _barglyphs, _desc_color, _bar_color, numprintedvalues, Any[])
    end
end

function print_progress(output::IO, p::Progress)
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
    printover(output, prefix*p.desc, bar_str, p.desc_color, p.bar_color)
    printvalues!(output, p, p.current_values; prefix_color=p.desc_color, value_color=p.bar_color)

    # Compensate for any overhead of printing. This can be
    # especially important if you're running over a slow network
    # connection.
    p.tlast = t + 2*(time()-t)

    return nothing
end

function finish_progress(output, p::Progress)
    bar = barstring(p.barlen, 1, barglyphs=p.barglyphs)
    dur = durationstring(time()-p.tfirst)
    bar_str = @sprintf "100%%%s Time: %s" bar dur
    prefix = length(p.current_values) == 0 ? "[ " : "┌ "

    printover(output, prefix*p.desc, bar_str, p.desc_color, p.bar_color)
    printvalues!(output, p, p.current_values; prefix_color=p.desc_color, value_color=p.bar_color)
    println(output)
end

# Internal method to print additional values below progress bar
function printvalues!(output, p::Progress, showvalues; prefix_color, value_color)
    len = length(showvalues)
    len == 0 && return

    maxwidth = maximum(Int[length(string(name)) for (name, _) in showvalues])

    for (i, (name, value)) in enumerate(showvalues)
        prefix = i == len ? "\n└   " : "\n│   "
        msg = rpad(string(name) * ": ", maxwidth+2+1) * string(value)

        printstyled(output, prefix; color=prefix_color, bold=true)
        printstyled(output, msg; color=value_color)
    end
    p.numprintedvalues = length(showvalues)
end

function clear_lines(output, progs::Dict{Symbol, Progress})
    num_lines = 0
    for (id, p) in progs
        num_lines += p.numprintedvalues + 1
    end

    move_cursor_up_while_clearing_lines(output, num_lines - 1)
    print(output, "\r\u1b[K")
end