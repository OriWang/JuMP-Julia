export getDemandTrace, getPVTrace, getWindTrace
    
using DataFrames
using XLSX
using CSV

loadTraceFolderPath = joinpath(@__DIR__, "..", "data", "2013_NTNDP_Plexos_Database");

function parameterFolderPath(testCase) 
    parameterFolderPath = data_path = joinpath(@__DIR__, "..", "data", testCase);
end

function getDataFrame(testCase, metric)
    dataPath = parameterFolderPath(testCase);
    if !(lowercase(metric) in ["generator", "bus", "branch", "svc", "utility_storage"])
        println("ERROR: Parameter 2: metric is invalid.");
        return;
    end
    fileName = metric * ".csv";      # String concatenate
    dataframe = DataFrame(CSV.File(joinpath(dataPath, fileName)));
    dataframe = dataframe[1:end - 1, :];       # delete END OF DATA row
    return dataframe;
end

function getPVTrace(trace; header)
    filePath = loadTraceFolderPath;
    if trace == "NQ"
        filePath = joinpath(filePath,"Solar_Trace", "NQ Solar Real PV.csv");
    elseif trace == "CQ"
        filePath = joinpath(filePath,"Solar_Trace", "CQ Solar Real PV.csv");
    elseif trace == "SEQ"
        filePath = joinpath(filePath,"Solar_Trace", "SEQ Solar Real PV.csv");
    elseif trace == "SWQ"
        filePath = joinpath(filePath,"Solar_Trace", "SWQ Solar Real PV.csv");
    elseif trace == "NNS"
        filePath = joinpath(filePath,"Solar_Trace", "NNS Solar Real PV.csv");
    elseif trace == "NCEN"
        filePath = joinpath(filePath, "Solar_Trace", "NCEN Solar Real PV.csv");
    elseif trace == "CAN"
        filePath = joinpath(filePath, "Solar_Trace", "CAN Solar Real PV.csv");
    elseif trace == "SWNSW"
        filePath = joinpath(filePath, "Solar_Trace", "SWNSW Solar Real PV.csv");
    elseif trace == "CVIC"
        filePath = joinpath(filePath, "Solar_Trace", "CVIC Solar Real PV.csv");
    elseif trace == "NVIC"
        filePath = joinpath(filePath, "Solar_Trace", "NVIC Solar Real PV.csv");
    elseif trace == "MEL"
        filePath = joinpath(filePath, "Solar_Trace", "MEL Solar Real PV.csv");
    elseif trace == "LV"
        filePath = joinpath(filePath, "Solar_Trace", "LV Solar Real PV.csv");
    elseif trace == "SESA"
        filePath = joinpath(filePath, "Solar_Trace", "SESA Solar Real PV.csv");
    elseif trace == "ADE"
        filePath = joinpath(filePath, "Solar_Trace", "ADE Solar Real PV.csv");
    elseif trace == "NSA"
        filePath = joinpath(filePath, "Solar_Trace", "NSA Solar Real PV.csv");
    elseif trace == "N_North"
        filePath = joinpath(filePath, "N_North.csv");
    elseif trace == "N_South"
        filePath = joinpath(filePath, "N_South.csv");
    elseif trace == "N_East"
        filePath = joinpath(filePath, "N_East.csv");
    elseif trace == "N_West"
        filePath = joinpath(filePath, "N_West.csv");
    else 
        filePath = joinpath(filePath, trace * ".csv");
    end

    dataframe = DataFrame(CSV.File(filePath, header=header));
    return dataframe;
end


function getDemandTrace(trace)
    filePath = loadTraceFolderPath;
    if trace == "QLD"
        filePath = joinpath(loadTraceFolderPath, "ESOO_2013_Load_Traces", "2013 ESOO QLD1 Planning 10POE_0910refyr.csv");
    elseif trace == "NSW"
        filePath = joinpath(loadTraceFolderPath, "ESOO_2013_Load_Traces", "2013 ESOO NSW1 Planning 10POE_0910refyr.csv");
    elseif trace == "VIC"
        filePath = joinpath(loadTraceFolderPath, "ESOO_2013_Load_Traces", "2013 ESOO VIC1 Planning 10POE_0910refyr.csv");
    elseif trace == "SA"
        filePath = joinpath(loadTraceFolderPath, "ESOO_2013_Load_Traces", "2013 ESOO SA1 Planning 10POE_0910refyr.csv");
    elseif trace == "TAS"
        filePath = joinpath(loadTraceFolderPath, "ESOO_2013_Load_Traces", "2013 ESOO TAS1 Planning 10POE_0910refyr.csv");
    elseif trace == "N_North"
        filePath = joinpath(loadTraceFolderPath, "N_North.csv");
    elseif trace == "N_South"
        filePath = joinpath(loadTraceFolderPath, "N_South.csv");
    elseif trace == "N_East"
        filePath = joinpath(loadTraceFolderPath, "N_East.csv");
    elseif trace == "N_West"
        filePath = joinpath(loadTraceFolderPath, "N_West.csv");
    else
        filePath = joinpath(loadTraceFolderPath, trace * ".csv");
    end

    dataframe = DataFrame(CSV.File(filePath, header=0));
    if dataframe[1, 1] == "Year"
        # Remove the header row
        dataframe = dataframe[2:end, :]
    end
    return dataframe;
end


function getWindTrace(trace; header)
    filePath = loadTraceFolderPath;
    if trace == "NQ"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"NQ T1.csv");
    elseif trace == "CQ"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"NQ T2.csv");
    elseif trace == "SEQ"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"SWQ T2.csv");
    elseif trace == "SWQ"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"SWQ T1.csv");
    elseif trace == "NNS"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"NNS T1.csv");
    elseif trace == "NCEN"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"NCEN T1.csv");
    elseif trace == "CAN"
        filePath= joinpath(filePath,"0910_Wind_Traces" ,"CAN T1.csv");
    elseif elsetrace == "SWNSW"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"SWNSW T1.csv");
    elseif trace == "NVIC"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"CVIC T1.csv");
    elseif trace == "CVIC"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"CVIC T1.csv");
    elseif trace == "MEL"
        filePath= joinpath(filePath,"0910_Wind_Traces" ,"MEL T1.csv");
    elseif trace == "LV"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"LV T1.csv");
    elseif trace == "SESA"
        filePath = joinpath(filePath,"0910_Wind_Traces" ,"SESA T1.csv");
    elseif trace == "ADE"
        filePath= joinpath(filePath,"0910_Wind_Traces" ,"SESA T2.csv");
    elseif trace == "NSA"
        filePath= joinpath(filePath,"0910_Wind_Traces" ,"NSA T1.csv");
    elseif trace == "N_North"
        filePath = jonipath(filePath, "N_North.csv");
    elseif trace == "N_South"
        filePath = jonipath(filePath, "N_South.csv");
    elseif trace == "N_East"
        filePath = jonipath(filePath, "N_East.csv");
    elseif trace == "N_West"
        filePath = jonipath(filePath, "N_West.csv");
    else 
        filePath = joinpath(filePath, trace * ".csv");
    end

    dataframe = DataFrame(CSV.File(filePath, header=header));
    return dataframe;
end # End of function



