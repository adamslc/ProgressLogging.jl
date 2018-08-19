module ProgressLogging

using Logging, Printf
import Logging: handle_message, shouldlog, min_enabled_level
export ProgressLogger, Progress, BarGlyphs, with_progress, @progress

include("BarGlyphs.jl")
include("utils.jl")
include("Progress.jl")

const ProgressLevel = Logging.LogLevel(-1)

mutable struct ProgressLogger <: AbstractLogger
	parent_logger::AbstractLogger
    p::Progress

    ProgressLogger(p::Progress) = new(current_logger(), p)
end
ProgressLogger(; kwargs...) = ProgressLogger(Progress(; kwargs...))

function handle_message(logger::ProgressLogger, level, message, mod, group, id,
						file, line; kwargs...)
	if haskey(kwargs, :progress)
        if kwargs[:progress] == "done" || kwargs[:progress] >= 1
            finish_progress(logger.p)
            return
        end

		logger.p.progress = kwargs[:progress]
		time() < logger.p.tlast + logger.p.dt && return
		current_values = Any[]
		for (key, value) in kwargs
			key_str = string(key)
			if key_str[1] != '_' && key_str != "progress"
                push!(current_values, (key_str, value))
            end
		end
		logger.p.current_values = current_values

        check_clear_lines(logger.p)
		print_progress(logger.p)
        check_float(logger.p)
	elseif Logging.min_enabled_level(logger.parent_logger) <= level &&
           Logging.shouldlog(logger.parent_logger, level, mod, group, id)

        check_clear_lines(logger.p, clear_first_line=true)
		Logging.handle_message(logger.parent_logger, level, message, mod, group,
                               id, file, line; kwargs...)
        check_float(logger.p)
	end
end
shouldlog(p::ProgressLogger, level, args...) = true
min_enabled_level(p::ProgressLogger) =
    min(Logging.LogLevel(-2), min_enabled_level(p.parent_logger))

macro progress(prog)
    :(@logmsg(ProgressLevel, "", progress=$(esc(prog)), _module=nothing, _group=nothing, _id=nothing, _file=nothing, _line=nothing))
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