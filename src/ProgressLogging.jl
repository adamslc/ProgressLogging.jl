module ProgressLogging

using Logging, Printf
import Logging: handle_message, shouldlog, min_enabled_level, catch_exceptions
export ProgressLogger, Progress, BarGlyphs, with_progress, @progress

include("BarGlyphs.jl")
include("utils.jl")
include("Progress.jl")

const ProgressLevel = Logging.LogLevel(-1)

mutable struct ProgressLogger <: AbstractLogger
	parent_logger::AbstractLogger
    p::Dict{Symbol, Progress}

    ProgressLogger() = new(current_logger(), Dict{Symbol, Progress}())
end

function handle_message(logger::ProgressLogger, level, message, mod, group, id,
						file, line; kwargs...)
	if haskey(kwargs, :progress)
        if !haskey(logger.p, id)
            if kwargs[:progress] == "done" || kwargs[:progress] >= 1
                return
            end
            logger.p[id] = Progress()
        end

        if kwargs[:progress] == "done" || kwargs[:progress] >= 1
            finish_progress(logger.p[id])
            delete!(logger.p, id)
        else
            logger.p[id].progress = kwargs[:progress]
            time() < logger.p[id].tlast + logger.p[id].dt && return

    		current_values = Any[]
    		for (key, value) in kwargs
    			key_str = string(key)
    			if key_str[1] != '_' && key_str != "progress"
                    push!(current_values, (key_str, value))
                end
    		end
    		logger.p[id].current_values = current_values
        end

        num_should_clear = 0
        for (id, p) in logger.p
            check_clear_lines(p, clear_first_line=true)

            if p.printed
                num_should_clear += 1
            end
        end

        move_cursor_up_while_clearing_lines(stderr, num_should_clear - 1)

        for (i, (id, p)) in enumerate(logger.p)
            print_progress(p)
            i != length(logger.p) && println()
            # check_float(p)
        end
	elseif Logging.min_enabled_level(logger.parent_logger) <= level &&
           Logging.shouldlog(logger.parent_logger, level, mod, group, id)

        for (id, p) in logger.p
            check_clear_lines(p, clear_first_line=true)
        end
        move_cursor_up_while_clearing_lines(stderr, length(logger.p) - 1)
        print("\r\u1b[K")

		Logging.handle_message(logger.parent_logger, level, message, mod, group,
                               id, file, line; kwargs...)

        for (i, (id, p)) in enumerate(logger.p)
            print_progress(p)
            i != length(logger.p) && println()
            # check_float(p)
        end
	end
end
shouldlog(p::ProgressLogger, level, args...) = true
min_enabled_level(p::ProgressLogger) =
    min(Logging.LogLevel(-2), min_enabled_level(p.parent_logger))
catch_exceptions(::ProgressLogger) = false

macro progress(prog)
    :(@logmsg(ProgressLevel, "", progress=$(esc(prog)), _module=nothing, _group=nothing, _file=nothing, _line=nothing))
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