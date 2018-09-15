using ProgressLogging, Test, Random

Random.seed!(1)

function f(N)
    @warn "starting"
    for i in 1:N
        i % 10 == 0 && @info "stuff"

        sleep(0.05)
        @progress :PROGRESS "Progress: " i/N
    end
    @error "finished"
end

with_progress() do
    @progress(:outer_progress, "Outer progress: ", 0)
    for i in 1:5
        f(50)
        @progress(:outer_progress, "Outer progress: ", i/5)
    end
end