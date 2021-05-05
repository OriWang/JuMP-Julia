using Dates
using Query
using DataFrames, CSV

include("data_reader.jl");

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
    # If year, month, day are String value, change the input dateArray to String
    if typeof(longTermData[2, 1]) == String
        year = string(dateArray[1]);
        month = string(dateArray[2]);
        day = string(dateArray[3]);
    elseif typeof(longTermData[2, 1]) == Int64
        year = dateArray[1];
        month = dateArray[2];
        day = dateArray[3];
    end
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
    generator_df = getDataFrame(testCase, "generator");
    gen_num = length(generator_df[:, 1]);

    bus_df = getDataFrame(testCase, "bus");
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
    branch_df = getDataFrame(testCase, "branch");
    line_num = length(branch_df[:, 1]);

    bus_df = getDataFrame(testCase, "bus");

    links = [];

    for i in 1:line_num
        end1BusName = branch_df[i, 2];
        end1BusId = findfirst(x -> x == end1BusName, bus_df[:, 1]);
        push!(links, (i, end1BusId))
    end

    return links
end


function getLineEnd2BusLinks(testCase)
    branch_df = getDataFrame(testCase, "branch");
    line_num = length(branch_df[:, 1]);

    bus_df = getDataFrame(testCase, "bus");

    links = [];

    for i in 1:line_num
        end2BusName = branch_df[i, 3];
        end2BusId = findfirst(x -> x == end2BusName, bus_df[:, 1]);
        push!(links, (i, end2BusId))
    end

    return links
end

function getBusKeyDict(testCase, valueMetric)
    bus_df = getDataFrame(testCase, "bus");
    busNum = length(bus_df[:, 1]);
    linkArray = [];
    if valueMetric == "generator"
        linkArray = getGenBusLinks(testCase);
    elseif valueMetric == "lineEnd1"
        linkArray = getLineEnd1BusLinks(testCase);
    elseif valueMetric == "lineEnd2"
        linkArray = getLineEnd2BusLinks(testCase);
    else 
        println("ERROR: Arg 2 should be 'generator', 'lineEnd1', or 'lineEnd2'.");
        return;
    end
    result = Dict()

    # Set empty array as value for buses without a generator connected.
    for i in 1:busNum
        result[i] = [];
    end

    for (value, bus) in linkArray
        # bus must exists in the keys because all buses are added.
        result[bus] = append!(result[bus], value)
    end
    return result
end

function getBusKeyDictFromLinks(linkArray)
    bus_df = getDataFrame(testCase, "bus");
    busNum = length(bus_df[:, 1]);

    result = Dict()

    # Set empty array as value for buses without a generator connected.
    for i in 1:busNum
        result[i] = [];
    end

    for (value, bus) in linkArray
        result[bus] = append!(result[bus], value);
    end
    return result;
end

