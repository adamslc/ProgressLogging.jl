module ProgressLogging

using Logging, Printf
import Logging: handle_message, shouldlog, min_enabled_level
export ProgressLogger, BarGlyphs, with_progress, @progress

include("BarGlyphs.jl")
include("utils.jl")

const ProgressLevel = Logging.LogLevel(-1)

mutable struct ProgressLogger <: AbstractLogger
	parent_logger::AbstractLogger
	output::IO

	percentage::Real
	
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

	function ProgressLogger(; dt=0.1, desc="Progress: ", desc_color=:green,
							bar_color=:color_normal, output=stderr,
							barlen=tty_width(desc), float::Bool=true,
							barglyphs=BarGlyphs('|','█','█',' ','|'))
		percentage = 0.
		tfirst = tlast = time()
		printed = false
		numprintedvalues = 0

		new(current_logger(), output, percentage, tfirst, tlast, dt, printed,
			desc, barlen, barglyphs, desc_color, bar_color, float,
            numprintedvalues, Any[])
	end
end

function handle_message(p::ProgressLogger, level, message, mod, group, id,
						file, line; kwargs...)
	if haskey(kwargs, :progress)
        if kwargs[:progress] == "done"
            finish_progress(p)
            return
        end

		p.percentage = kwargs[:progress]
		time() < p.tlast + p.dt && return
		current_values = Any[]
		for (key, value) in kwargs
			key_str = string(key)
			if key_str[1] != '_' && key_str != "progress"
                push!(current_values, (key_str, value))
            end
		end
		p.current_values = current_values

		p.printed && p.float && move_cursor_up_while_clearing_lines(p.output, p.numprintedvalues)
		print_progress(p)
        p.float || println(p.output)
	else
		p.printed && p.float && move_cursor_up_while_clearing_lines(p.output, p.numprintedvalues)
		p.printed && p.float && print("\r\u1b[K")

		if Logging.min_enabled_level(p.parent_logger) <= level && Logging.shouldlog(p.parent_logger, level, mod, group, id)
			Logging.handle_message(p.parent_logger, level, message, mod, group, id, file, line; kwargs...)
		end

		p.float && print_progress(p)
	end
end
function shouldlog(p::ProgressLogger, level, args...)
    return true
end
min_enabled_level(p::ProgressLogger) = min(Logging.LogLevel(-2), min_enabled_level(p.parent_logger))

function print_progress(p::ProgressLogger)
    t = time()

    p.percentage > 1 && return

    bar = barstring(p.barlen, p.percentage, barglyphs=p.barglyphs)
    elapsed_time = t - p.tfirst
    est_total_time = elapsed_time / p.percentage
    if 0 <= est_total_time <= typemax(Int)
        eta_sec = round(Int, est_total_time - elapsed_time )
        eta = durationstring(eta_sec)
    else
        eta = "N/A"
    end
	bar_str = @sprintf "%3u%%%s  ETA: %s" round(Int, 100*p.percentage) bar eta

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

function finish_progress(p::ProgressLogger)
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
function printvalues!(p::ProgressLogger, showvalues; prefix_color=false, value_color=false)
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

macro progress(percentage)
    :(@logmsg(ProgressLevel, "", progress=$(esc(percentage)), _module=nothing, _group=nothing, _id=nothing, _file=nothing, _line=nothing))
end

function with_progress(f::Function; kwargs...)
    Logging.disable_logging(Logging.LogLevel(-2))
	logger = ProgressLogger(; kwargs...)
	with_logger(logger) do
		f()
        @progress "done"
	end
end

end # module