"""
DEBUG NOTES: 
Unknown data: PV_trace_DR

Problem found:
In test1 and 14Gen, MUT is column P (16); while in ColePaker, MUT is column Q (17)
""";

include("data_reader.jl");
include("supporting_functions.jl");

## Load data
using DataFrames
using XLSX, CSV

testCase = "ColeParker"     # The folder name of the test case

generator_df = getDataFrame(testCase, "generator");
bus_df = getDataFrame(testCase, "bus");
branch_df = getDataFrame(testCase, "branch");
utility_storage_df = getDataFrame(testCase, "utility_storage")

demandTraceList = bus_df[:, 17];

# Read data about power loading
pathOf = Dict();
demandTraceDataframeMap = Dict();
oneDayLoadOfDemandTrace = Dict();
current_day = [2020, 1, 2];

for demandTraceCode in demandTraceList
    # pathOf[demandTraceCode] = getDemandTrace(demandTraceCode);
    demandTraceDataframeMap[demandTraceCode] = getDemandTrace(demandTraceCode, header=0);    # For test1 input, there's no header
    # oneDayLoadOfDemandTrace[demandTraceCode] = demandTraceDataframeMap[demandTraceCode][current_day, 4:end];
    oneDayLoadOfDemandTrace[demandTraceCode] = getDataForOneDay(current_day, demandTraceDataframeMap[demandTraceCode])
end


## MAST model
using JuMP, GLPK, LinearAlgebra, DataFrames

# Controller flag parameters
en_Uty_Strg = size(utility_storage_df)[1] >= 1;
en_Uty_Strg = false;
en_DR_PV = false;
en_DR_Strg = false;

# en_Uty_Strg = true;
# en_DR = true;
# en_DR_PV = true;
# en_DR_Strg = true;
en_Type2 = count(i -> i == 2, generator_df[:, 18]) >= 1;
en_Type3 = count(i -> i == 3, generator_df[:, 18]) >= 1;



# Set declaration


gen_num = length(generator_df[:, 1]);
UGen = 1:gen_num;
G_T1 = findall(i -> i == 1, generator_df[:, 18]);     # Find the indices of all generators for each type
G_T2  = findall(i -> i == 2, generator_df[:, 18]);    # Type2 generators sets
G_T3 = findall(i -> i == 3, generator_df[:, 18]);     # Type3 generators sets
G_Syn = findall(techCode -> isSyn(techCode), generator_df[:, 20]);      # Synchronous generators sets

bus_num = length(bus_df[:, 1]);
UBus = 1:bus_num;

branch_num = length(branch_df[:, 1]);
ULine = 1:branch_num;

regionList = bus_df[:, 2];
region_num = length(Set(regionList))
URegion = 1:region_num;

# Utility Storage sets
utility_num = length(utility_storage_df[:, 1]);
UStorage = 1:utility_num;
Storage_Bus_links = [(s, b) for s in UStorage for b in UBus];

T = 24;     # One-hour slots
Time = 1:T;

# Cross sets links
Gen_Bus_links  = getGenBusLinks(testCase);
Gen_Region_links = [(g, r) for g in UGen for r in URegion];
GenT1_Region_links = [(g1, r) for g1 in G_T1 for r in URegion];
Line_end1_Bus_links = getLineEnd1BusLinks(testCase);    # (Line, End1 bus)
Line_end2_Bus_links = getLineEnd2BusLinks(testCase);
Bus_Region_links = [(b, r) for b in UBus for r in URegion];

# Type3 Generators Cross Sets
if en_Type3
    GenT3_Region_links = [(g3, r) for g3 in G_T3 for r in URegion];
end

# Generator cost parameters
C_Fix = generator_df[:, 6];     # Fixed cost
C_Su = generator_df[:, 7];      # Start up cost
C_Sd = generator_df[:, 8];      # Shut down cost
C_Var = generator_df[:, 9];     # Variable cost

# Generator parameters
Max_pwr = generator_df[:, 10];  # Maximum real power
Min_pwr = generator_df[:, 11];  # Minimum real power
Ramp_up = generator_df[:, 14];  # Ramp up rate
Ramp_down = generator_df[:, 15];    # Ramp down rate
MUT = generator_df[:, 16];      # MUT
MDT = generator_df[:, 17];      # MDT
Units = generator_df[:, 3];     # Number of units

# Generator initial conditions
# TODO: Update before calculation for next day.
Status_ini = zeros(gen_num);
Pwr_Gen_ini = zeros(gen_num);
MUT_ini = zeros(gen_num, T);
MDT_ini = zeros(gen_num, T);


# Interconnector parameter
ThrmLim = branch_df[:, 8];        # Thermal limit (MVA)
Susceptance = branch_df[:, 10];   # Susceptance (pu)

# Demand parameters
Consumer_ratio = ones(bus_num) - bus_df[:, 6] / 100;
Consumer_ratio = ones(bus_num)  # set as 1 to simplify
# alpha = ones(bus_num);       # alpha means Consumer demand ratio
alpha = Consumer_ratio;      # use consumer_ratio instead of alpha to be more readable
en_DR = Consumer_ratio < ones(bus_num);

Demand = zeros(bus_num, T);
Csm_Demand = zeros(bus_num, T);
Psm_Demand = zeros(bus_num, T);
Demand_Trace_Weightage = bus_df[:, 4];
busRegionCount = length(Set(bus_df[:, 2]));
if round(sum(Demand_Trace_Weightage) / busRegionCount) == 100
    # weightage is written in percentage, so divided by 100
    Demand_Trace_Weightage /= 100;
end
for i in 1:bus_num
    demandTrace = bus_df[i, 17];
    Demand[i, :] = convert(Array, oneDayLoadOfDemandTrace[demandTrace]) * Demand_Trace_Weightage[i];
    Csm_Demand[i, :] = Demand[i, :] * Consumer_ratio[i];
    Psm_Demand[i, :] = Demand[i, :] * (1 - Consumer_ratio[i]);
end

Loss_factor = 0.1;
PReserve_factor = 0.1;

# Type2 Generators Parameters
if en_Type2
    Resource_trace_T2 = 200 * ones(length(G_T2), T);     # matrix_generator_x_time[G_T2, Time]    # TODO: replace the placeholder
end

# Type3 Generators Parameters
if en_Type3
    Resource_trace_T3 = 20 * randn(length(G_T3), T);           # matrix_generator_x_time[G_T3, Time]    # TODO: replace the placeholder
    Enrg_TES_ini = zeros(length(G_T3));                        # TODO: replace the placeholder
    TES_eff = generator_df[:, 24][G_T3] / 100;                 # TES Efficiency (%)
    Min_SOC_TES = generator_df[:, 23][G_T3];                   # Minimum TES Limit (MWh)
    Max_SOC_TES = generator_df[:, 22][G_T3];                   # Maximum TES Capacity (MWh)
end

if en_Uty_Strg
    # Utility Storage sets and parameters
    Chrg_rate_strg = utility_storage_df[:, 6];      # Maximum Charge Rate (MW/h)
    Dchrg_rate_strg = utility_storage_df[:, 7];     # Maximum Discharge Rate (MW/h)
    Min_SOC_strg = parse.(Int64, utility_storage_df[:, 5]);        # Minimum Storage Capacity (MWh)
    Max_SOC_strg = utility_storage_df[:, 4];        # Maximum Storage Capacity (MWh)
    Storage_eff = utility_storage_df[:, 8] / 100;   # Storage Efficiency (0 ~ 1)

    # Utility Storage initial conditions
    Enrg_Strg_ini = zeros(utility_num);     # TODO: placeholder
end

# Demand response parameters
if en_DR
    M_gp = 1e6;
    M_gn = 1e6;
    M_bal = 1e6;
    M_pv = 1e6;
    M_sp = 1e6;
    M_pl = 1e6;
    M_pu = -1e6;
    M_el = 1e6;
    M_eu = -1e6;
    # TODO: Need to replace with real data
    # PV_trace_DR{UBus,Time} >= 0;
    Max_chrg_rate_bat = bus_df[:, 11];      # Maximum Charge Rate (MW/h)
    Max_dchrg_rate_bat = bus_df[:, 12];      # Maximum Discharge Rate (MW/h)
    Min_SOC_bat = bus_df[:, 10];            # Minimum Battery Capacity (MWh)
    Max_SOC_bat = bus_df[:, 9];             # Maximum Battery Capacity (MWh)
    Bat_eff = bus_df[:, 13] / 100;          # Battery Efficiency (0 ~ 1)

    # Demand response initial conditions
    # TODO: Update before the calculation for next day's data.
    Engy_bat_ini = zeros(bus_num);
end


## Model defination
mast = Model(GLPK.Optimizer);

# Generator Decision variable
@variable(mast, 0 <= Status_var[g in UGen, t in Time] <= Units[g], Int);
@variable(mast, S_Up_var[UGen, Time] >= 0, Int);
@variable(mast, S_Down_var[UGen, Time] >= 0, Int);
@variable(mast, Pwr_Gen_var[UGen, Time] >= 0);

# Interconnector Decision Variables
@variable(mast, Pwr_line_var[ULine, Time]);

# Node Angle Decision Variables
@variable(mast, Angle_line_var[UBus, Time]);

# Type3 Generators variables
if en_Type3
    @variable(mast, Enrg_TES_var[G_T3,Time] >= 0);
    @variable(mast, GenT3_Rsv_var[G_T3,Time] >= 0);
    @variable(mast, Pwr_Spill_var[G_T3,Time] >= 0);
end

# Utility storage decision variables
if en_Uty_Strg
    @variable(mast, Pwr_chrg_Strg_var[UStorage, Time] >= 0)
    @variable(mast, Pwr_dchrg_Strg_var[UStorage, Time] >= 0)
    @variable(mast, Enrg_Strg_var[UStorage, Time] >= 0)
end

# Demand Response
if en_DR
    # Demand response decision variables
    @variable(mast, Pwr_pgp_var[UBus, Time] >= 0);
    @variable(mast, Pwr_pgn_var[UBus, Time] >= 0);
    @variable(mast, Pwr_bal_var[UBus, Time] >= 0);
    @variable(mast, Pwr_pv_var[UBus, Time] >= 0);
    @variable(mast, Pwr_sp_var[UBus, Time] >= 0);
    @variable(mast, Engy_bat_var[UBus, Time] >= 0);
    @variable(mast, Pwr_bat_var[UBus, Time]);

    # Slackness Variables
    # Dual Variable for equality constraints
    @variable(mast, lambda_pg_var[UBus,Time]);
    @variable(mast, lambda_pb_var[UBus,Time]);
    @variable(mast, lambda_pv_var[UBus,Time]);
    @variable(mast, lambda_e_var[UBus,Time]);
    # Dual Variable for inequality constraints
    @variable(mast, mu_gp_var[UBus,Time] >= 0);
    @variable(mast, mu_gn_var[UBus,Time] >= 0);
    @variable(mast, mu_pb_var[UBus,Time] >= 0);
    @variable(mast, mu_pl_var[UBus,Time] >= 0);
    @variable(mast, mu_pu_var[UBus,Time] >= 0);
    @variable(mast, mu_el_var[UBus,Time] >= 0);
    @variable(mast, mu_eu_var[UBus,Time] >= 0);
    @variable(mast, mu_pv_var[UBus,Time] >= 0);
    @variable(mast, mu_sp_var[UBus,Time] >= 0);

    # Orthognal maintaining Variables
    @variable(mast, b_gp_var[UBus,Time], Bin);
    @variable(mast, b_gn_var[UBus,Time], Bin);
    @variable(mast, b_bal_var[UBus,Time], Bin);
    @variable(mast, b_pv_var[UBus,Time], Bin);
    @variable(mast, b_sp_var[UBus,Time], Bin);
    @variable(mast, b_pl_var[UBus,Time], Bin);
    @variable(mast, b_pu_var[UBus,Time], Bin);
    @variable(mast, b_el_var[UBus,Time], Bin);
    @variable(mast, b_eu_var[UBus,Time], Bin);
end

## Objective function
total_cost = sum(
    C_Fix[g] * Status_var[g, t]
    + C_Su[g] * S_Up_var[g, t]
    + C_Sd[g] * S_Down_var[g, t]
    + C_Var[g] * Pwr_Gen_var[g, t]
    for g in UGen for t in Time
);
@objective(mast, Min, total_cost);

## Power balance constraint
# Use (flag ? expression : 0) to control the constraint
# Use `abs < a small positive` to show two floats are identical.



"""
@constraint(mast, Power_Balance[b in UBus, t in Time],
    0 <= (
        sum(Pwr_Gen_var[g, t] for (g, b) in Gen_Bus_links)
        + sum(Pwr_line_var[l1, t] for (l1, b) in Line_end1_Bus_links)
        - (
            Csm_Demand[b, t]
            + Loss_factor * Csm_Demand[b, t]
            + sum(Pwr_line_var[l2, t] for (l2, b) in Line_end2_Bus_links)
            + (en_Uty_Strg ? sum((Pwr_chrg_Strg_var[s,t] - Pwr_dchrg_Strg_var[s,t]) for (s, b) in Storage_Bus_links) : 0)
            + (en_DR ? (
                Pwr_pgp_var[b,t]
                + Loss_factor * Pwr_pgp_var[b,t]
                - Pwr_pgn_var[b,t]
                + Loss_factor * Pwr_pgn_var[b,t]
                ) : 0)
        )
    ) <= 1E-3
);
"""

busGenDict = getBusKeyDict(testCase, "generator");
bus1LineDict = getBusKeyDict(testCase, "lineEnd1");
bus2LineDict = getBusKeyDict(testCase, "lineEnd2");
if en_DR_Strg
    busStorageDict = getBusKeyDict(testCase, "storage");
end

@constraint(mast, Power_Balance[b in UBus, t in Time],
    sum(Pwr_Gen_var[g, t] for g in busGenDict[b]) 
    + sum(Pwr_line_var[l1, t] for l1 in bus1LineDict[b]) 
    == (
        Csm_Demand[b, t]
        + Loss_factor * Csm_Demand[b, t]
        + sum(Pwr_line_var[l2, t] for l2 in bus2LineDict[b])
        + (en_Uty_Strg ? sum((Pwr_chrg_Strg_var[s,t] - Pwr_dchrg_Strg_var[s,t]) for s in busStorageDict[b]) : 0)
        + (en_DR ? (
            Pwr_pgp_var[b,t]
            + Loss_factor * Pwr_pgp_var[b,t]
            - Pwr_pgn_var[b,t]
            + Loss_factor * Pwr_pgn_var[b,t]
            ) : 0)
    )
);

# difference_array = [(
#                 (isempty(busGenDict[b]) ? 0 : sum(Pwr_Gen_var[g, t] for g in busGenDict[b]))
#                + (isempty(busGenDict[b]) ? 0 : sum(Pwr_line_var[l1, t] for l1 in bus1LineDict[b]))
#                - (
#                    Csm_Demand[b, t]
#                    + Loss_factor * Csm_Demand[b, t]
#                    + (isempty(busGenDict[b]) ? 0 : sum(Pwr_line_var[l2, t] for l2 in bus2LineDict[b]))
#                    + (en_Uty_Strg ? sum((Pwr_chrg_Strg_var[s,t] - Pwr_dchrg_Strg_var[s,t]) for (s, b) in Storage_Bus_links) : 0)
#                    + (en_DR ? (
#                        Pwr_pgp_var[b,t]
#                        + Loss_factor * Pwr_pgp_var[b,t]
#                        - Pwr_pgn_var[b,t]
#                        + Loss_factor * Pwr_pgn_var[b,t]
#                        ) : 0)
#                ))  for b in UBus, t in Time];




## Generator Constraints, Stable Limit
# Syn Generators
if typeof(Max_pwr[1]) == String
    Max_pwr = parse.(Float64, Max_pwr);
end
@constraint(mast, Gen_max_pwr[g in G_Syn, t in Time],
        Pwr_Gen_var[g,t] <= Max_pwr[g] * Status_var[g,t]);
@constraint(mast, Gen_min_pwr[g in G_Syn, t in Time],
        Min_pwr[g] * Status_var[g,t] <= Pwr_Gen_var[g,t]);

# Integer variable linking Constraint
@constraint(mast, On_Off[g in G_Syn, t in 2:T],
        S_Up_var[g,t] - S_Down_var[g,t]
        == Status_var[g,t] - Status_var[g,t - 1]
);
@constraint(mast, On_Off_initial[g in G_Syn],
        S_Up_var[g,1] - S_Down_var[g,1]
        == Status_var[g,1] - Status_ini[g]
);
println("Line 337 finished");


# Generator Ramping Constraints, using 'if' to express '==>'

# @constraint(mast, ramp_up[g in G_Syn, t in 2:T],
#        (Ramp_up[g] < Max_pwr[g]) => {Pwr_Gen_var[g,t] - Pwr_Gen_var[g,t-1] <= Status_var[g,t] * Ramp_up[g]});
for g in G_Syn, t in 2:T
    if Ramp_up[g] < Max_pwr[g]
        @constraint(mast, Pwr_Gen_var[g,t] - Pwr_Gen_var[g,t - 1] <= Status_var[g,t] * Ramp_up[g]);
    end
end

# @constraint(mast, ramp_up_initial[g in G_Syn],
#        Ramp_up[g] >= Max_pwr[g] || Pwr_Gen_var[g,1] - Pwr_Gen_ini[g] <= Status_var[g,1]*Ramp_up[g]);
for g in G_Syn
    if Ramp_up[g] < Max_pwr[g]
        @constraint(mast, Pwr_Gen_var[g,1] - Pwr_Gen_ini[g] <= Status_var[g,1] * Ramp_up[g]);
    end
end
# @constraint(mast, ramp_down[g in G_Syn, t in 2:T],
#        Ramp_down[g] >= Max_pwr[g] || Pwr_Gen_var[g,t-1] - Pwr_Gen_var[g,t] <= Status_var[g,t-1]*Ramp_down[g]);
for g in G_Syn, t in 2:T
    if Ramp_down[g] < Max_pwr[g]
        @constraint(mast, Pwr_Gen_var[g,t - 1] - Pwr_Gen_var[g,t] <= Status_var[g,t - 1] * Ramp_down[g]);
    end
end
println("Line 367 finished");

# @constraint(mast, ramp_down_initial[g in G_Syn],
#        Ramp_down[g] >= Max_pwr[g] || Pwr_Gen_ini[g] - Pwr_Gen_var[g,1] <= Status_ini[g]*Ramp_down[g]);
for g in G_Syn
    if Ramp_down[g] < Max_pwr[g]
        @constraint(mast, Pwr_Gen_ini[g] - Pwr_Gen_var[g,1] <= Status_ini[g] * Ramp_down[g]);
    end
end
println("Line 376 finished.");

# Generator Minimum Up/Down Time Constraints
# min_up_Time
for g in G_Syn, t in MUT[g]:T
    if MUT[g] > 1
        @constraint(mast, Status_var[g,t] >= sum(S_Up_var[g, t - t1] for t1 in 0:MUT[g] - 1));
    end
end

# min_up_Time_ini
for g in G_Syn, t in 1:(MUT[g] - 1)
    if MUT[g] > 1
        @constraint(mast, Status_var[g,t] >= sum(S_Up_var[g,t - t1] for t1 in 0:t - 1) + MUT_ini[g,t]);
    end
end
println("Line 394 finished");

# min_down_Time
for g in G_Syn, t in MDT[g]:T
    if MDT[g] > 1
        @constraint(mast, Status_var[g,t] <= Units[g] - sum(S_Down_var[g,t - t1] for t1 in 0:MDT[g] - 1));
    end
end

# min_down_Time_ini
for g in G_Syn, t in 1:MDT[g] - 1
    if MDT[g] > 1
        @constraint(mast, Status_var[g,t] <= Units[g] - sum(S_Down_var[g, t - t1] for t1 in 0:t - 1) - MDT_ini[g,t]);
    end
end


# Maximum limit on ON units
@constraint(mast, max_ONunits[g in UGen, t in Time],
       Status_var[g,t] <= Units[g]);
println("Line 412 finished.");

## Interconnect constraints
# Thermal limits
@constraint(mast, thermal_limit_ub[l in ULine, t in Time],
        Pwr_line_var[l,t] <= ThrmLim[l]);
@constraint(mast, thermal_limit_lb[l in ULine, t in Time],
        -ThrmLim[l] <= Pwr_line_var[l,t]);


# AC line angle stability, COMMENT: Time consumming part, TODO: Need to check the values
lineBus1Dict = getLineBus1Dict(testCase);
lineBus2Dict = getLineBus2Dict(testCase);
@constraint(mast, angle_limit[l in ULine, t in Time],
        Pwr_line_var[l,t] == Susceptance[l] * (
            sum(Angle_line_var[b1,t] for b1 in lineBus1Dict[l])
            - sum(Angle_line_var[b2,t] for b2 in lineBus2Dict[l])
            )
);
println("Line 428 finished");


## Type2 (PV and Wind) generator additional constraints
if en_Type2
    # RES constraints
    # Type2 Power Limit
    @constraint(mast, Resource_availability_T2[g in G_T2, t in Time],
                Pwr_Gen_var[g,t] <= Status_var[g,t] * Resource_trace_T2[g,t]);
    @constraint(mast, G_T2_min_pwr[g in G_T2, t in Time],
                Status_var[g,t] * Min_pwr[g] <= Pwr_Gen_var[g,t]);
end


## Type3 (CSP) generator additional constraints
if en_Type3
    # CST constraints
    # Type3 Generators Power Limit
    @constraint(mast, TES_SOC[g in G_T3, t in 2:T],
            Enrg_TES_var[g,t]
            == TES_eff[g] * Enrg_TES_var[g,t - 1]
            + Resource_trace_T3[g,t]
            - Pwr_Gen_var[g,t]
            - Pwr_Spill_var[g,t]
    );
    @constraint(mast, TES_SOC_ini[g in G_T3],
            Enrg_TES_var[g,1]
            == TES_eff[g] * Enrg_TES_ini[g]
            + Resource_trace_T3[g,1]
            - Pwr_Gen_var[g,1]
            - Pwr_Spill_var[g,1]
    );

    # Type3 Generators Active Power Reserve Limits
    # Reserve limited by Generation
    @constraint(mast, GenT3_Rsv_power_limit[g in G_T3, t in Time],
            GenT3_Rsv_var[g,t] <= Status_var[g,t] * Max_pwr[g] - Pwr_Gen_var[g,t]);

    # Reserve limited by Storage
    @constraint(mast, GenT3_Rsv_energy_limit[g in G_T3, t in Time],
            GenT3_Rsv_var[g,t] <= Enrg_TES_var[g,t] - Pwr_Gen_var[g,t]);

    # CST TES SOC Limits
    @constraint(mast, Min_TES_SOC[g in G_T3, t in Time],
            Enrg_TES_var[g,t] >= Min_SOC_TES[g]);
    @constraint(mast, Max_TES_SOC[g in G_T3, t in Time],
            Enrg_TES_var[g,t] <= Max_SOC_TES[g]);
end


## Utility Storage Constrints
if en_Uty_Strg
    # Utility Storage Energy Balance Constraint
    @constraint(mast, Storage_energy_balance[s in UStorage, t in 2:T],
                Enrg_Strg_var[s, t]
                == Storage_eff[s] * Enrg_Strg_var[s, t - 1]
                + Pwr_chrg_Strg_var[s, t]
                - Pwr_dchrg_Strg_var[s, t]
    )
    @constraint(mast, Storage_energy_balance_Initial[s in UStorage],
                Enrg_Strg_var[s, 1]
                == Storage_eff[s] * Enrg_Strg_ini[s]
                + Pwr_chrg_Strg_var[s,1]
                - Pwr_dchrg_Strg_var[s,1]
    )

    # Charge/Discharge rate constraints
    @constraint(mast, Charge_rate_Storage[s in UStorage, t in Time],
                Pwr_chrg_Strg_var[s,t] <= Chrg_rate_strg[s]
    )
    @constraint(mast, DCharge_rate_Storage[s in UStorage, t in Time],
                Pwr_dchrg_Strg_var[s,t] <= Dchrg_rate_strg[s]
    )

    # Storage SOC constraints
    @constraint(mast, Min_SOC_Strg[s in UStorage, t in Time],
                Enrg_Strg_var[s,t] >= Min_SOC_strg[s]
    )
    @constraint(mast, Max_SOC_Strg[s in UStorage, t in Time],
                 Enrg_Strg_var[s,t] <= Max_SOC_strg[s]
    )
end

println("Line 509 Completed");
## Demand Response
if en_DR
    # DR Equality Constraints
    #   KKT Constraints
    @constraint(mast, KKT_pgp[p in UBus, t in Time],
        lambda_pg_var[p,t] - mu_gp_var[p,t]  == -1);
    @constraint(mast, KKT_fdin[p in UBus, t in Time],
        - lambda_pg_var[p,t] - mu_gn_var[p,t]  == alpha[p]);
    @constraint(mast, KKT_pbat[p in UBus, t in Time],
        -lambda_pb_var[p,t] - lambda_e_var[p,t] - mu_pl_var[p,t] + mu_pu_var[p,t] == 0);
    @constraint(mast, KKT_ppv[p in UBus, t in Time],
        lambda_pg_var[p,t] + lambda_pv_var[p,t] - mu_pv_var[p,t] == 0);
    @constraint(mast, KKT_pspill[p in UBus, t in Time],
        lambda_pv_var[p,t] - mu_sp_var[p,t] == 0);
    @constraint(mast, KKT_bald[p in UBus, t in Time],
        -lambda_pg_var[p,t] + lambda_pb_var[p,t] - mu_pb_var[p,t] == 0);
    @constraint(mast, KKT_ebat[p in UBus, t in 1:(T - 1)],
        lambda_e_var[p,t]
        - Bat_eff[p] * lambda_e_var[p,t]
        - mu_el_var[p,t] 
        + mu_eu_var[p,t]
        == 0
    );

    # System equality constraints
    @constraint(mast, Grid_bus_bal[p in UBus, t in Time],
        Pwr_pgp_var[p,t] + Pwr_pv_var[p,t] - Pwr_pgn_var[p,t] - Pwr_bal_var[p,t] == 0);
    @constraint(mast, Load_bus_bal[p in UBus, t in Time],
        Pwr_bal_var[p,t] - Pwr_bat_var[p,t] == Psm_Demand[p,t]);
    @constraint(mast, PV_bus_bal[p in UBus, t in Time],
        Pwr_pv_var[p,t] + Pwr_sp_var[p,t] == PV_trace_DR[p,t]);     # ERROR PV_trace_DR not defined
    @constraint(mast, Battery_SOC[p in UBus, t in 2:T],
            Engy_bat_var[p,t]
            - Bat_eff[p] * Engy_bat_var[p,t - 1]
            - Pwr_bat_var[p,t]
            == 0
    );
    @constraint(mast, Battery_SOC_Initial[p in UBus],
            Engy_bat_var[p,1]
            - Bat_eff[p] * Engy_bat_ini[p]
            - Pwr_bat_var[p,1]
            == 0
    );

    # Inequality Constraints
    # Orthogonal Constraints
    # Prosumer grid power intake
    @constraint(mast, mu_gp_perp_pgp_A[p in UBus, t in Time],
            Pwr_pgp_var[p,t] <= M_gp * b_gp_var[p,t]);
    @constraint(mast, mu_gp_perp_pgp_B[p in UBus, t in Time],
            mu_gp_var[p,t] <= M_gp * (1 - b_gp_var[p,t]) );

    # Prosumer feeding power
    @constraint(mast, mu_gn_perp_pgn_A[p in UBus, t in Time],
            Pwr_pgn_var[p,t] <= M_gn * b_gn_var[p,t]);
    @constraint(mast, mu_gn_perp_pgn_B[p in UBus, t in Time],
            mu_gn_var[p,t] <= M_gn * (1 - b_gn_var[p,t]) );

    # Prosumer battery and load power
    @constraint(mast, mu_pb_perp_bal_A[p in UBus, t in Time],
            Pwr_bal_var[p,t] <= M_bal * b_bal_var[p,t]);
    @constraint(mast, mu_pb_perp_bal_B[p in UBus, t in Time],
            mu_pb_var[p,t] <= M_bal * (1 - b_bal_var[p,t]) );

    # Prosumer PV power
    @constraint(mast, mu_pv_perp_ppv_A[p in UBus, t in Time],
            Pwr_pv_var[p,t] <= M_pv * b_pv_var[p,t]);
    @constraint(mast, mu_pv_perp_ppv_B[p in UBus, t in Time],
            mu_pv_var[p,t] <= M_pv * (1 - b_pv_var[p,t]) );

    # Prosumer PV-spilled
    @constraint(mast, mu_sp_perp_psp_A[p in UBus, t in Time],
            Pwr_sp_var[p,t] <= M_sp * b_sp_var[p,t]);
    @constraint(mast, mu_sp_perp_psp_B[p in UBus, t in Time],
            mu_sp_var[p,t] <= M_sp * (1 - b_sp_var[p,t]) );

    # Battery discharge limit
    @constraint(mast, mu_pl_perp_pb_A[p in UBus, t in Time],
            Pwr_bat_var[p,t] <= M_pl * b_pl_var[p,t]);
    @constraint(mast, mu_pl_perp_pb_B[p in UBus, t in Time],
            mu_pl_var[p,t] <= M_pl * (1 - b_pl_var[p,t]) );
    @constraint(mast, mu_pl_perp_pb_C[p in UBus, t in Time],
            Pwr_bat_var[p,t] >= Max_dchrg_rate_bat[p] );

    # Battery charge limit
    @constraint(mast, mu_pu_perp_pb_A[p in UBus, t in Time],
            Pwr_bat_var[p,t] >= M_pu * b_pu_var[p,t]);
    @constraint(mast, mu_pu_perp_pb_B[p in UBus, t in Time],
            mu_pu_var[p,t] <= M_pu * (1 - b_pu_var[p,t]) );
    @constraint(mast, mu_pu_perp_pb_C[p in UBus, t in Time],
            Pwr_bat_var[p,t] <= Max_chrg_rate_bat[p] );

    # Battery lower SOC limit
    @constraint(mast, mu_el_perp_eb_A[p in UBus, t in Time],
            Engy_bat_var[p,t] <= M_el * b_el_var[p,t]);
    @constraint(mast, mu_el_perp_eb_B[p in UBus, t in Time],
            mu_el_var[p,t] <= M_el * (1 - b_el_var[p,t]) );
    @constraint(mast, mu_el_perp_eb_C[p in UBus, t in Time],
            Engy_bat_var[p,t] >= Min_SOC_bat[p] );

    # Battery charge limit
    @constraint(mast, mu_eu_perp_eb_A[p in UBus, t in Time],
            Engy_bat_var[p,t] >= M_eu * b_eu_var[p,t]);
    @constraint(mast, mu_eu_perp_eb_B[p in UBus, t in Time],
            mu_eu_var[p,t] <= M_eu * (1 - b_eu_var[p,t]) );
    @constraint(mast, mu_eu_perp_eb_C[p in UBus, t in Time],
            Engy_bat_var[p,t] <= Max_SOC_bat[p] );
end

println("Line 620 completed");


## Optimize
println("Calculating...");
optimize!(mast)
print("The minimum cost is \$$(objective_value(mast))");
