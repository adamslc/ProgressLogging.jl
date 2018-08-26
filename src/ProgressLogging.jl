module ProgressLogging

import Printf: @sprintf

using Logging
import Logging: handle_message, shouldlog, min_enabled_level, catch_exceptions,
                LogLevel

# import Base.CoreLogging: logmsg_code, _min_enabled_level, current_logger_for_env

export ProgressLogger, Progress, BarGlyphs, with_progress, @progress

include("BarGlyphs.jl")
include("utils.jl")
include("Progress.jl")

const ProgressLevel = LogLevel(-1)

mutable struct ProgressLogger <: AbstractLogger
	parent_logger::AbstractLogger
    output::IO
    p::Dict{Symbol, Progress}

    ProgressLogger() = new(current_logger(), stderr, Dict{Symbol, Progress}())
end

function handle_message(logger::ProgressLogger, level, message, mod, group, id,
						file, line; kwargs...)
	if haskey(kwargs, :progress)
        if !haskey(logger.p, id)
            if kwargs[:progress] == "done" || kwargs[:progress] >= 1
                return
            end
            logger.p[id] = Progress(message; kwargs...)
            println(logger.output)
        end

        if kwargs[:progress] == "done" || kwargs[:progress] >= 1
            clear_lines(logger.output, logger.p)
            finish_progress(logger.output, logger.p[id])
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

            clear_lines(logger.output, logger.p)
        end

        for (i, (id, p)) in enumerate(logger.p)
            print_progress(logger.output, p)
            i != length(logger.p) && println()
        end
	elseif min_enabled_level(logger.parent_logger) <= level &&
           shouldlog(logger.parent_logger, level, mod, group, id)

        clear_lines(logger.output, logger.p)

		handle_message(logger.parent_logger, level, message, mod, group,
                               id, file, line; kwargs...)

        for (i, (id, p)) in enumerate(logger.p)
            print_progress(logger.output, p)
            i != length(logger.p) && println(logger.output)
        end
	end
end
shouldlog(p::ProgressLogger, level, args...) = true
min_enabled_level(p::ProgressLogger) =
    min(LogLevel(-2), min_enabled_level(p.parent_logger))
catch_exceptions(::ProgressLogger) = false

# macro progress(id, msg, prog, kwargs...)
#     logmsg_code(nothing, nothing, nothing, ProgressLevel, msg,
#         :(_id=id), :(_group=nothing), :(progress=prog), kwargs...)
# end
macro progress(id, msg, prog, kwargs...)
    esc_kwargs = [esc(k) for k in kwargs]

    :(@logmsg(ProgressLevel, $(esc(msg)), _id=$(esc(id)), progress=$(esc(prog)),
        _module=nothing, _group=nothing, _file=nothing, _line=nothing,
        $(esc_kwargs...)))
end

function with_progress(f::Function; kwargs...)
    disable_logging(LogLevel(-2))
	logger = ProgressLogger(; kwargs...)
	with_logger(logger) do
		f()
	end
end

end # module