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
# en_Uty_Strg = false;
# en_DR = false;
# en_DR_PV = true;
# en_DR_Strg = true;
en_Uty_Strg = true;
en_DR = true;
en_DR_PV = true;
en_DR_Strg = true;
en_Type2 = count(i -> i == 2, generator_df[18, 1]) >= 1;
en_Type3 = true; #count(i -> i == 3, generator_df[18, 1]) >= 1;
# set to true temporary to test all code.


# Set declaration
gen_num = length(generator_df[1, 1]);
UGen = 1:gen_num;
G_Syn = 1:gen_num;      # TODO: Need to change G_Syn as a subset of UGen
G_T1 = findall(i -> i==1, generator_df[18, 1]);     # Find the indices of all type 1 generators

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
# TODO: Did not find in excel file, use placeholders instead.
Status_ini = zeros(gen_num);
Pwr_Gen_ini = zeros(gen_num);
MUT_ini = zeros(gen_num, T);
MDT_ini = zeros(gen_num, T);


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
if en_Uty_Strg
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


## Generator Constraints, Stable Limit
# Syn Generators
@constraint(mast, Gen_max_pwr[g in G_Syn, t in Time],
        Pwr_Gen_var[g,t] <= Max_pwr[g] * Status_var[g,t]);
@constraint(mast, Gen_min_pwr[g in G_Syn, t in Time], 
        Min_pwr[g]*Status_var[g,t] <= Pwr_Gen_var[g,t]);

# Integer variable linking Constraint
@constraint(mast, On_Off[g in G_Syn, t in 2:T], 
        S_Up_var[g,t] - S_Down_var[g,t] 
        == Status_var[g,t] - Status_var[g,t-1]
);
@constraint(mast, On_Off_initial[g in G_Syn], 
        S_Up_var[g,1] - S_Down_var[g,1] 
        == Status_var[g,1] - Status_ini[g]
);

# Generator Ramping Constraints, using (a ==> b) <=> (!a || b)
@constraint(mast, ramp_up[g in G_Syn, t in 2:T], 
       Ramp_up[g] >= Max_pwr[g] || Pwr_Gen_var[g,t] - Pwr_Gen_var[g,t-1] <= Status_var[g,t]*Ramp_up[g]);        # ERROR: Cannot use ||
@constraint(mast, ramp_up_initial[g in G_Syn], 
       Ramp_up[g] >= Max_pwr[g] || Pwr_Gen_var[g,1] - Pwr_Gen_ini[g] <= Status_var[g,1]*Ramp_up[g]);
@constraint(mast, ramp_down[g in G_Syn, t in 2:T], 
       Ramp_down[g] >= Max_pwr[g] || Pwr_Gen_var[g,t-1] - Pwr_Gen_var[g,t] <= Status_var[g,t-1]*Ramp_down[g]);
@constraint(mast, ramp_down_initial[g in G_Syn], 
       Ramp_down[g] >= Max_pwr[g] || Pwr_Gen_ini[g] - Pwr_Gen_var[g,1] <= Status_ini[g]*Ramp_down[g]);

# Generator Minimum Up/Down Time Constraints
@constraint(mast, min_up_Time[g in G_Syn, t in MUT[g]:T], 
       MUT[g] <= 1 || Status_var[g,t] >= sum(S_Up_var[g, t-t1] for t1 in 0:MUT[g]-1));
@constraint(mast, min_up_Time_ini[g in G_Syn, t in 1:(MUT[g]-1)], 
       MUT[g] <= 1 || Status_var[g,t] >= sum(S_Up_var[g,t-t1] for t1 in 0:t-1) + MUT_ini[g,t]);

@constraint(mast, min_down_Time[g in G_Syn, t in MDT[g]:T], 
       MDT[g] <= 1 || Status_var[g,t] <= Units[g] - sum(S_Down_var[g,t-t1] for t1 in 0:MDT[g]-1));
@constraint(mast, min_down_Time_ini[g in G_Syn, t in 1:MDT[g]-1], 
       MDT[g] <= 1 || Status_var[g,t]\n <= Units[g] - sum(S_Down_var[g,t-t1] for t1 in 0:t-1) - MDT_ini[g,t]);

# Maximum limit on ON units
@constraint(mast, max_ONunits[g in UGen, t in Time],
       Status_var[g,t] <= Units[g]);


## Interconnect constraints
# Thermal limits
@constraint(mast, thermal_limit_ub[l in ULine, t in Time],
        Pwr_line_var[l,t] <= ThrmLim[l]);
@constraint(mast, thermal_limit_lb[l in ULine, t in Time], 
        -ThrmLim[l] <= Pwr_line_var[l,t]);

# AC line angle stability
@constraint(mast, angle_limit[l in ULine, t in Time], 
        Pwr_line_var[l,t] == Susceptance[l] * (
            sum(Angle_line_var[n1,t] for (l,n1) in Line_end1_Node_links)
            - sum(Angle_line_var[n2,t] for (l,n2) in Line_end2_Node_links )
            )
);


## Type2 (PV and Wind) generator additional constraints
if en_Type2
    # RES generator parameters
    # Type2 Generators Sets
    G_T2  = findall(i -> i == 2, generator_df[18, 1]);

    # Type2 Generators Parameters
    Resource_trace_T2 = 200 * ones(length(G_T2), T);     # matrix_generator_x_time[G_T2, Time]    # TODO: replace the placeholder

    # RES constraints
    # Type2 Power Limit
    @constraint(mast, Resource_availability_T2[g in G_T2, t in Time],
                Pwr_Gen_var[g,t] <= Status_var[g,t] * Resource_trace_T2[g,t]);
    @constraint(mast, G_T2_min_pwr[g in G_T2, t in Time], 
                Status_var[g,t] * Min_pwr[g] <= Pwr_Gen_var[g,t]);
end





## Utility Storage Constrints
if en_Uty_Strg
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


## Demand Response
if en_DR
    # Demand response parameters
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
    # PV_trace_DR{UNode,Time} >= 0;
    Max_chrg_rate_bat = bus_df[11, 1];      # Maximum Charge Rate (MW/h)
    Max_dchrg_rate_bat= bus_df[12, 1];      # Maximum Discharge Rate (MW/h)       
    Min_SOC_bat = bus_df[10, 1];            # Minimum Battery Capacity (MWh)
    Max_SOC_bat = bus_df[9, 1];             # Maximum Battery Capacity (MWh)
    Bat_eff = bus_df[13, 1] / 100;          # Battery Efficiency (0 ~ 1)
    # alpha{UNode} >= 0;       # TODO: What's alpha?

    # Demand response initial conditions
    # TODO: replace with real data
    Engy_bat_ini = zeros(bus_num);

    # Demand response decision variables
    @variable(mast, Pwr_pgp_var[UNode, Time] >= 0);
    @variable(mast, Pwr_pgn_var[UNode, Time] >= 0);
    @variable(mast, Pwr_bal_var[UNode, Time] >= 0);
    @variable(mast, Pwr_pv_var[UNode, Time] >= 0);
    @variable(mast, Pwr_sp_var[UNode, Time] >= 0);
    @variable(mast, Engy_bat_var[UNode, Time] >= 0);
    @variable(mast, Pwr_bat_var[UNode, Time]);

    # Slackness Variables
    # Dual Variable for equality constraints
    @variable(mast, lambda_pg_var[UNode,Time]);
    @variable(mast, lambda_pb_var[UNode,Time]);
    @variable(mast, lambda_pv_var[UNode,Time]);
    @variable(mast, lambda_e_var[UNode,Time]);
    # Dual Variable for inequality constraints
    @variable(mast, mu_gp_var[UNode,Time] >= 0);
    @variable(mast, mu_gn_var[UNode,Time] >= 0);
    @variable(mast, mu_pb_var[UNode,Time] >= 0);
    @variable(mast, mu_pl_var[UNode,Time] >= 0);
    @variable(mast, mu_pu_var[UNode,Time] >= 0);
    @variable(mast, mu_el_var[UNode,Time] >= 0);
    @variable(mast, mu_eu_var[UNode,Time] >= 0);
    @variable(mast, mu_pv_var[UNode,Time] >= 0);
    @variable(mast, mu_sp_var[UNode,Time] >= 0);
    # Orthognal maintaining Variables
    @variable(mast, b_gp_var[UNode,Time], Bin);
    @variable(mast, b_gn_var[UNode,Time], Bin);
    @variable(mast, b_bal_var[UNode,Time], Bin);
    @variable(mast, b_pv_var[UNode,Time], Bin);
    @variable(mast, b_sp_var[UNode,Time], Bin);
    @variable(mast, b_pl_var[UNode,Time], Bin);
    @variable(mast, b_pu_var[UNode,Time], Bin);
    @variable(mast, b_el_var[UNode,Time], Bin);
    @variable(mast, b_eu_var[UNode,Time], Bin);

    # DR Constraints
    #   KKT Constraints
    @constraint(mast, KKT_pgp[p in UNode, t in Time],
        lambda_pg_var[p,t] - mu_gp_var[p,t]  == -1);
    @constraint(mast, KKT_fdin[p in UNode, t in Time],
        - lambda_pg_var[p,t] - mu_gn_var[p,t]  == alpha[p]);    # ERROR # LINK: Line 190
    @constraint(mast, KKT_pbat[p in UNode, t in Time],
        -lambda_pb_var[p,t] - lambda_e_var[p,t] - mu_pl_var[p,t] + mu_pu_var[p,t] == 0);
    @constraint(mast, KKT_ppv[p in UNode, t in Time],
        lambda_pg_var[p,t] + lambda_pv_var[p,t] - mu_pv_var[p,t] == 0);
    @constraint(mast, KKT_pspill[p in UNode, t in Time],
        lambda_pv_var[p,t] - mu_sp_var[p,t] == 0);
    @constraint(mast, KKT_bald[p in UNode, t in Time],
        -lambda_pg_var[p,t] + lambda_pb_var[p,t] - mu_pb_var[p,t] == 0);
    @constraint(mast, KKT_ebat[p in UNode, t in 1:(T-1)],
        lambda_e_var[p,t] 
        - Bat_eff[p] * lambda_e_var[p,t] 
        - mu_el_var[p,t] + mu_eu_var[p,t]
        == 0
    );

    # System equality constraints
    @constraint(mast, Grid_bus_bal[p in UNode, t in Time],
        Pwr_pgp_var[p,t] + Pwr_pv_var[p,t] - Pwr_pgn_var[p,t] - Pwr_bal_var[p,t] == 0);
    @constraint(mast, Load_bus_bal[p in UNode, t in Time],
        Pwr_bal_var[p,t] - Pwr_bat_var[p,t] == Psm_Demand[p,t]);
    @constraint(mast, PV_bus_bal[p in UNode, t in Time],
        Pwr_pv_var[p,t] + Pwr_sp_var[p,t] == PV_trace_DR[p,t]);     # ERROR #LINK line 184
    @constraint(mast, Battery_SOC[p in UNode, t in 2:T],
            Engy_bat_var[p,t] 
            - Bat_eff[p] * Engy_bat_var[p,t-1] 
            - Pwr_bat_var[p,t] 
            == 0
    );
    @constraint(mast, Battery_SOC_Initial[p in UNode],
            Engy_bat_var[p,1] 
            - Bat_eff[p] * Engy_bat_ini[p] 
            - Pwr_bat_var[p,1]  
            == 0 
    );

    # Inequality Constraints
    # Orthogonal Constraints
    # Prosumer grid power intake
    @constraint(mast, mu_gp_perp_pgp_A[p in UNode, t in Time],
            Pwr_pgp_var[p,t] <= M_gp*b_gp_var[p,t]);
    @constraint(mast, mu_gp_perp_pgp_B[p in UNode, t in Time],
            mu_gp_var[p,t] <= M_gp * (1 - b_gp_var[p,t]) );

    # Prosumer feeding power
    @constraint(mast, mu_gn_perp_pgn_A[p in UNode, t in Time],
            Pwr_pgn_var[p,t] <= M_gn*b_gn_var[p,t]);
    @constraint(mast, mu_gn_perp_pgn_B[p in UNode, t in Time],
            mu_gn_var[p,t] <= M_gn * (1 - b_gn_var[p,t]) );

    # Prosumer battery and load power
    @constraint(mast, mu_pb_perp_bal_A[p in UNode, t in Time],
            Pwr_bal_var[p,t] <= M_bal*b_bal_var[p,t]);
    @constraint(mast, mu_pb_perp_bal_B[p in UNode, t in Time],
            mu_pb_var[p,t] <= M_bal * (1 - b_bal_var[p,t]) );

    # Prosumer PV power
    @constraint(mast, mu_pv_perp_ppv_A[p in UNode, t in Time],
            Pwr_pv_var[p,t] <= M_pv*b_pv_var[p,t]);
    @constraint(mast, mu_pv_perp_ppv_B[p in UNode, t in Time],
            mu_pv_var[p,t] <= M_pv * (1 - b_pv_var[p,t]) );

    # Prosumer PV-spilled
    @constraint(mast, mu_sp_perp_psp_A[p in UNode, t in Time],
            Pwr_sp_var[p,t] <= M_sp*b_sp_var[p,t]);
    @constraint(mast, mu_sp_perp_psp_B[p in UNode, t in Time],
            mu_sp_var[p,t] <= M_sp * (1 - b_sp_var[p,t]) );

    # Battery discharge limit
    @constraint(mast, mu_pl_perp_pb_A[p in UNode, t in Time],
            Pwr_bat_var[p,t] <= M_pl*b_pl_var[p,t]);
    @constraint(mast, mu_pl_perp_pb_B[p in UNode, t in Time],
            mu_pl_var[p,t] <= M_pl * (1 - b_pl_var[p,t]) );
    @constraint(mast, mu_pl_perp_pb_C[p in UNode, t in Time],
            Pwr_bat_var[p,t] >= Max_dchrg_rate_bat[p] );

    # Battery charge limit
    @constraint(mast, mu_pu_perp_pb_A[p in UNode, t in Time],
            Pwr_bat_var[p,t] >= M_pu*b_pu_var[p,t]);
    @constraint(mast, mu_pu_perp_pb_B[p in UNode, t in Time],
            mu_pu_var[p,t] <= M_pu * (1 - b_pu_var[p,t]) );
    @constraint(mast, mu_pu_perp_pb_C[p in UNode, t in Time],
            Pwr_bat_var[p,t] <= Max_chrg_rate_bat[p] );

    # Battery lower SOC limit
    @constraint(mast, mu_el_perp_eb_A[p in UNode, t in Time],
            Engy_bat_var[p,t] <= M_el*b_el_var[p,t]);
    @constraint(mast, mu_el_perp_eb_B[p in UNode, t in Time],
            mu_el_var[p,t] <= M_el * (1 - b_el_var[p,t]) );
    @constraint(mast, mu_el_perp_eb_C[p in UNode, t in Time],
            Engy_bat_var[p,t] >= Min_SOC_bat[p] );

    # Battery charge limit
    @constraint(mast, mu_eu_perp_eb_A[p in UNode, t in Time],
            Engy_bat_var[p,t] >= M_eu*b_eu_var[p,t]);
    @constraint(mast, mu_eu_perp_eb_B[p in UNode, t in Time],
            mu_eu_var[p,t] <= M_eu * (1 - b_eu_var[p,t]) );
    @constraint(mast, mu_eu_perp_eb_C[p in UNode, t in Time],
            Engy_bat_var[p,t] <= Max_SOC_bat[p] );
end
