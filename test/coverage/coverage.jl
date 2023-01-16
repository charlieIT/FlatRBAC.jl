using Coverage

cd(joinpath(@__DIR__, "..", "..")) do
    # process '*.cov' files
    coverage = process_folder() # defaults to src/; alternatively, supply the folder name as argument
    # Get total coverage for all Julia files
    covered_lines, total_lines = get_summary(coverage)
    percentage = covered_lines / total_lines * 100
    percentage = round(percentage, digits=2)

    open(joinpath(pwd(), "lcov.info"), "w") do io
        LCOV.write(io, coverage)
    end;

    println("Coverage: ($(percentage)%) covered")

    cleanup = Base.parse(Bool, get(ENV, "cleanup", "true"))
    if cleanup
        [Coverage.clean_folder(path) for path in [joinpath(pwd(), "src"), joinpath(pwd(), "test")]];
    end
end
