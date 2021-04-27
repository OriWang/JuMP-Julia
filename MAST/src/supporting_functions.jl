using Dates
using Query

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