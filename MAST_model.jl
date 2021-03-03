## Load data
using DataFrames
using XLSX

data_path = joinpath(@__DIR__, "Test1.xlsx");
generator_df = DataFrame(XLSX.readtable(data_path, "Generator Data"))
bus_df = DataFrame(XLSX.readtable(data_path, "Bus Data"))
branch_df = DataFrame(XLSX.readtable(data_path, "Branch Data"))
utility_storage_df = DataFrame(XLSX.readtable(data_path, "Utility Storage Data"))

## MAST model
using JuMP, GLPK, LinearAlgebra, DataFrames

# Default Parameters
# En_Uty_Strg = false;
# En_DR = false;
# En_DR_PV = true;
# En_DR_Strg = true;
En_Uty_Strg = true;
En_DR = true;
En_DR_PV = true;
En_DR_Strg = true;

# Set declaration
gen_num = length(generator_df[1, 1]);
UGen = 1:gen_num;
bus_num = length(bus_df[1, 1]);
UNode = 1:bus_num;
branch_num = length(branch_df[1, 1]);
ULine = 1:branch_num;


T = 24;     # ? Not sure
Time = 1:T;
# node_num    # What's UNode?

# Cross set generation
Gen_Node_links  = [(g, n) for g in UGen for n in UNode];
Line_end1_Node_links = [(l, n) for l in ULine for n in UNode];
Line_end2_Node_links = [(l, n) for l in ULine for n in UNode];

# Generator cost
C_Fix = generator_df[6, 1];     # Fixed cost
C_Su = generator_df[7, 1];      # Start up cost
C_Sd = generator_df[8, 1];      # Shut down cost
C_Var = generator_df[9, 1];     # Variable cost

# Generator parameters
Max_pwr = generator_df[10, 1];  # Maximum real power
Min_pwr = generator_df[11, 1];  # Minimum real power
Ramp_up = generator_df[14, 1];  # Ramp up rate
Ramp_down = generator_df[15, 1];    # Ramp down rate
MUT = generator_df[16, 1];      # MUT
MDT = generator_df[17, 1];      # MDT
Units = generator_df[3, 1];     # Number of units

# Generator initial conditions
# TODO: Did not find in excel file

# Interconnector parameter
ThrmLim = branch_df[8, 1];      # Thermal limit (MVA)
Susceptance = branch_df[7, 1]   # Susceptance (pu)

# Demand parameters
# TODO: Not found in excel file, using placeholder instead
Csm_Demand = 300 * ones(bus_num, T);
Psm_Demand = 300 * ones(bus_num, T);
Loss_factor = 0.1;
PReserve_factor = 0.1;





## Model defination
mast = Model(GLPK.Optimizer);

# Decision variable
@variable(mast, 0 <= Status_var[g in UGen, t in Time] <= Units[g], Int)
@variable(mast, S_Up_var[UGen, Time] >= 0, Int)
@variable(mast, S_Down_var[UGen, Time] >= 0, Int)
@variable(mast, Pwr_Gen_var[UGen, Time] >= 0)

@variable(mast, Pwr_line_var[ULine, Time])
@variable(mast, Angle_line_var[UNode, Time])

# Objective function
total_cost = sum(
    C_Fix[g] * Status_var[g, t]
    + C_Su[g] * S_Up_var[g, t]
    + C_Sd[g] * S_Down_var[g, t]
    + C_Var[g] * Pwr_Gen_var[g, t]
    for g in UGen for t in Time
);
@objective(mast, Min, total_cost)

# Power balance constraint
if En_Uty_Strg
    # Utility Storage sets and parameters
    utility_num = length(utility_storage_df[1, 1]);
    UStorage = 1:utility_num;
    Storage_Node_links = [(s, n) for s in UStorage for n in UNode];

    Chrg_rate_strg = utility_storage_df[6, 1];      # Maximum Charge Rate (MW/h)
    Dchrg_rate_strg = utility_storage_df[7, 1];     # Maximum Discharge Rate (MW/h)
    Min_SOC_strg = utility_storage_df[5, 1];        # Minimum Storage Capacity (MWh)
    Max_SOC_strg = utility_storage_df[4, 1];        # Maximum Storage Capacity (MWh)
    Storage_eff = utility_storage_df[8, 1] / 100;   # Storage Efficiency (0 ~ 1)

    Enrg_Strg_ini = zeros(utility_num);     # TODO: placeholder
        
    # Utility storage variables
    @variable(mast, Pwr_chrg_Strg_var[UStorage, Time] >= 0)
    @variable(mast, Pwr_dchrg_Strg_var[UStorage, Time] >= 0)
    @variable(mast, Enrg_Strg_var[UStorage, Time] >= 0)

    @constraint(mast, Power_Balance[n in UNode, t in Time],
                sum(Pwr_Gen_var[g, t] for (g, n) in Gen_Node_links)
                + sum(Pwr_line_var[l1, t] for (l1, n) in Line_end1_Node_links)
                == Csm_Demand[n, t]
                + Loss_factor * Csm_Demand[n, t]
                + sum(Pwr_line_var[l2, t] for (l2, n) in Line_end2_Node_links)
                + sum((Pwr_chrg_Strg_var[s,t] - Pwr_dchrg_Strg_var[s,t]) for (s, n) in Storage_Node_links)

    )
else
    @constraint(mast, Power_Balance[n in UNode, t in Time],
                sum(Pwr_Gen_var[g, t] for (g, n) in Gen_Node_links)
                + sum(Pwr_line_var[l1, t] for (l1, n) in Line_end1_Node_links)
                == Csm_Demand[n, t]
                + Loss_factor * Csm_Demand[n, t]
                + sum(Pwr_line_var[l2, t] for (l2, n) in Line_end2_Node_links)
    )
end


## Utility Storage Constrints
if En_Uty_Strg
    # Utility Storage Energy Balance Constraint
    @constraint(mast, Storage_energy_balance[s in UStorage, t in 2:T],
                Enrg_Strg_var[s, t]
                == Storage_eff[s] * Enrg_Strg_var[s, t-1]
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

##
