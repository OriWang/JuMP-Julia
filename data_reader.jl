using DataFrames
using XLSX

data_path = joinpath(@__DIR__, "Test1.xlsx");
generator_df = DataFrame(XLSX.readtable(data_path, "Generator Data"))
bus_df = DataFrame(XLSX.readtable(data_path, "Bus Data"))
branch_df = DataFrame(XLSX.readtable(data_path, "Branch Data"))
utility_storage_df = DataFrame(XLSX.readtable(data_path, "Utility Storage Data"))

size(utility_storage_df)
print(names(generator_df))

generator_df[:, 1] #[n, 1] is the nth column

function isSyn(code)
    SynGenType = ["HYDR", "BlCT", "OCGT", "BrCT", "CCGT", "CoGen", "Sub Critical", "CST"];
    AsynGenType = ["WND"];
    if code in SynGenType
        return true;
    elseif code in AsynGenType
        return false;
    else 
        println("Wrong Type");
        return missing;
    end
end