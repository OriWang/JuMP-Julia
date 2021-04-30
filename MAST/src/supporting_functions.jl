using Dates
using Query
using DataFrames, CSV

function isSyn(techCode)
    SynGenType = ["HYDR", "BlCT", "OCGT", "BrCT", "CCGT", "CoGen", "Sub Critical", "CST"];
    AsynGenType = ["WND"];
    if techCode in SynGenType
        return true;
    elseif techCode in AsynGenType
        return false;
    else
        println("Wrong Type");
        return missing;
    end
end


function nextDayAfter(dateArray)
    year = dateArray[1];
    month = dateArray[2];
    day = dateArray[3];
    currentDay = Dates.Date(year, month, day);
    nextDay = currentDay + Dates.Day(1);
    return [Dates.year(nextDay), Dates.month(nextDay), Dates.day(nextDay)];
end


function getDataForOneDay(dateArray, longTermData)
    year = dateArray[1];
    month = dateArray[2];
    day = dateArray[3];
    if String.(names(longTermData))[1] == "Column1"
        queryResult = @from i in longTermData begin
                        @where i.Column1 == year && i.Column2 == month && i.Column3 == day
                        @select i
                        @collect DataFrame
        end
    elseif String.(names(longTermData))[1] == "Year"
        queryResult = @from i in longTermData begin
            @where i.Year == year && i.Month == month && i.Day == day
            @select i
            @collect DataFrame
        end
    else
        error("Wrong dataframe structure");
        return;
    end
    return queryResult[1, 4:end];
end


function getGenBusLinks(testCase)
    data_path = joinpath(@__DIR__, "..", "data", testCase);

    generator_df = DataFrame(CSV.File(joinpath(data_path, "generator.csv")))
    generator_df = generator_df[1:end - 1, :];       # delete END OF DATA row
    gen_num = length(generator_df[:, 1]);

    bus_df = DataFrame(CSV.File(joinpath(data_path, "bus.csv")));
    bus_df = bus_df[1:end - 1, :];
    bus_num = length(bus_df[:, 1]);

    links = [];

    for i in 1:gen_num
        busName = generator_df[i, 2];
        busId = findfirst(x -> x == busName, bus_df[:, 1]);
        push!(links, (i, busId))
    end

    return links
end


function getLineEnd1BusLinks(testCase)
    data_path = joinpath(@__DIR__, "..", "data", testCase);

    branch_df = DataFrame(CSV.File(joinpath(data_path, "branch.csv")))
    branch_df = branch_df[1:end - 1, :];       # delete END OF DATA row
    line_num = length(branch_df[:, 1]);

    bus_df = DataFrame(CSV.File(joinpath(data_path, "bus.csv")));
    bus_df = bus_df[1:end - 1, :];

    links = [];

    for i in 1:line_num
        end1BusName = branch_df[i, 2];
        end1BusId = findfirst(x -> x == end1BusName, bus_df[:, 1]);
        push!(links, (i, end1BusId))
    end

    return links
end


function getLineEnd2BusLinks(testCase)
    data_path = joinpath(@__DIR__, "..", "data", testCase);

    branch_df = DataFrame(CSV.File(joinpath(data_path, "branch.csv")))
    branch_df = branch_df[1:end - 1, :];       # delete END OF DATA row
    line_num = length(branch_df[:, 1]);

    bus_df = DataFrame(CSV.File(joinpath(data_path, "bus.csv")));
    bus_df = bus_df[1:end - 1, :];

    links = [];

    for i in 1:line_num
        end2BusName = branch_df[i, 3];
        end2BusId = findfirst(x -> x == end2BusName, bus_df[:, 1]);
        push!(links, (i, end2BusId))
    end

    return links
end

