#...length of bracket, percentage, and ETA string with days is 31 characters
tty_width(desc) = max(0, displaysize()[2] - (length(desc) + 31))

function move_cursor_up_while_clearing_lines(io, numlinesup)
    for _ in 1:numlinesup
        print(io, "\r\u1b[K\u1b[A")
    end
end

function printover(io::IO, desc, msg, desc_color=:color_normal, bar_color=:color_normal)
        print(io, "\r")         # go to first column
        printstyled(io, desc, color=desc_color, bold=true)
        printstyled(io, msg; color=bar_color)
        print(io, "\u1b[K")     # clear the rest of the line
end

function durationstring(nsec)
    days = div(nsec, 60*60*24)
    r = nsec - 60*60*24*days
    hours = div(r,60*60)
    r = r - 60*60*hours
    minutes = div(r, 60)
    seconds = r - 60*minutes

    hhmmss = @sprintf "%u:%02u:%02u" hours minutes seconds
    if days>9
        return @sprintf "%.2f days" nsec/(60*60*24)
    elseif days>0
        return @sprintf "%u days, %s" days hhmmss
    end
    hhmmss
end