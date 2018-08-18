# ProgressLogging.jl

This package implements a prototype for progress meters using Julia's new logging infrastructure. Most of the progress meter logic has been taken from Tim Holy's [ProgressMeter.jl](https://github.com/timholy/ProgressMeter.jl).

## Usage
To report progress information from a function, simply using the `@progress` macro. Feel free to mix in other logs.
```julia
function f(N)
    for i in 1:N
        i % 10 == 0 && @info "stuff"
        i == 3      && @error "bad stuff" rand(2, 2)

        sleep(0.05)
        @progress 100*i/N
    end
end
```

Now to capture and display the progress logs, wrap the function call using `with_progress`:
```julia
with_progress() do
    f(100)
end
```
By default, the progress meter will float below other logs. To disable this, pass the keyword argument `float=false` to `with_progress`. The `@progress` macro can also display values; simply pass keyword arguments like you would for a normal log.

## Future work
One of the primary goals of Julia's new logging infrastructure was to create a separation between the creation and display of log records. This allows library authors to log events without having to worry about how they will be displayed, and it give application authors a unified way to gather log information from all of the libraries that the application code uses.

The goal is to have a similar separation for progress logging:
* For library authors, `ProgressLoggingBase` will only define the `@progress` macro. This means that adding progress logging to a library requires a single lightweight dependency.
* Development environment authors (Juno, VS Code, REPL), can define custom `ProgressLogging[env]` packages that customize how progress logs are displayed in each environment.
* End users can include the `ProgressLogging` metapackage, which will automagically choose an appropriate `ProgressLogging[env]` package based on the environment it detects.