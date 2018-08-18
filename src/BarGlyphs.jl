"""
Holds the five characters that will be used to generate the progress bar.
"""
mutable struct BarGlyphs
    leftend::Char
    fill::Char
    front::Char
    empty::Char
    rightend::Char
end
"""
String constructor for BarGlyphs - will split the string into 5 chars
"""
function BarGlyphs(s::AbstractString)
    glyphs = (s...,)
    if !isa(glyphs, NTuple{5,Char})
        error("""
            Invalid string in BarGlyphs constructor.
            You supplied "$s".
            Note: string argument must be exactly 5 characters long, e.g. "[=> ]".
        """)
    end
    return BarGlyphs(glyphs...)
end

function barstring(barlen, percentage_complete; barglyphs::BarGlyphs=BarGlyphs('|','█','█',' ','|'))
    bar = ""
    if barlen>0
        if percentage_complete == 1 # if we're done, don't use the "front" character
            bar = string(barglyphs.leftend, repeat(string(barglyphs.fill), barlen), barglyphs.rightend)
        else
            nsolid = round(Int, barlen * percentage_complete)
            nempty = barlen - nsolid
            bar = string(barglyphs.leftend,
                         repeat(string(barglyphs.fill), max(0,nsolid-1)),
                         nsolid>0 ? barglyphs.front : "",
                         repeat(string(barglyphs.empty), nempty),
                         barglyphs.rightend)
        end
    end
    bar
end