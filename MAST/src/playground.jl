using DataFrames, CSV;

function getGenBusLink(testCase)
    data_path = joinpath(@__DIR__, "..", "data", testCase);

    generator_df = DataFrame(CSV.File(joinpath(data_path, "generator.csv")))
    generator_df = generator_df[1:end - 1, :];       # delete END OF DATA row
    gen_num = length(generator_df[:, 1]);

    bus_df = DataFrame(CSV.File(joinpath(data_path, "bus.csv")));
    bus_df = bus_df[1:end - 1, :];
    bus_num = length(bus_df[:, 1]);

    # a = [1, 4, 1, 2, 3, 2];
    # findall(x->x==2, a)
    # bus_gen_indices = Dict("N_West" => "G_Coal", "N_East" => "G_Gas" )
    link = [];

    for i in 1:gen_num
        busName = generator_df[i, 2];
        busId = findfirst(x -> x == busName, bus_df[:, 1]);
        push!(link, (i, busId))
    end

    return link
end


