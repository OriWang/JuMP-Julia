### SETS ###
set UGen;
set G_Syn in UGen;
set G_T1 in UGen;
param T>0;
set Time = 1..T;
set UBus;
set URegion;
set ULine;
	
### Type2 Generators Sets ###
set G_T2 in UGen;
	
### Type3 Generators Sets ###
set G_T3 in UGen;
	
	
### Utility Storage sets ###
set UStorage;
set Storage_Bus_links within (UStorage cross UBus);
	
### CROSS SETS LINKS ###
set Gen_Bus_links within (UGen cross UBus);
set Gen_Region_links within (UGen cross URegion);
set GenT1_Region_links within (G_T1 cross URegion);
set Line_end1_Bus_links within (ULine cross UBus);
set Line_end2_Bus_links within (ULine cross UBus);
set Bus_Region_links within (UBus cross URegion);


### Type3 Generators Cross Sets ###
set GenT3_Region_links within (G_T3 cross URegion);
### Generator Cost Parameters ###
param C_Fix{UGen} >=0;
param C_Su{UGen} >=0;
param C_Sd{UGen} >=0;
param C_Var{UGen} >=0;
	
### Generator Parameters ###
param Max_pwr{UGen} >=0;
param Min_pwr{UGen} >=0;
param Ramp_up{UGen} >=0;
param Ramp_down{UGen} >=0;
param MUT{UGen}>=0;
param MDT{UGen}>=0;
param Units{UGen}>=0;
	
### Generator Initial Consitions ###
param Status_ini{UGen} >=0;
param Pwr_Gen_ini{UGen} >=0;
param MUT_ini{UGen,1..24} >=0;
param MDT_ini{UGen,1..24} >=0;
	
### Interconnector Parameters ###
param ThrmLim{ULine} >=0;
param Susceptance{ULine};
	
### Demand Parameters ###
param Csm_Demand{UBus,Time} >=0;
param Psm_Demand{UBus,Time} >=0;
param Loss_factor >=0,<=1;
param PReserve_factor >=0,<=1;
	
### Type2 Generators Parameters ###
param Resource_trace_T2{G_T2,Time};
	
### Type3 Generators Parameters ###
param Resource_trace_T3{G_T3,Time};
param Enrg_TES_ini{G_T3};
param TES_eff{G_T3};
param Min_SOC_TES{G_T3} >=0;
param Max_SOC_TES{G_T3} >=0;
	
### Utility Storage parameters ###
param Chrg_rate_strg{UStorage} >=0;
param Dchrg_rate_strg{UStorage} >=0;
param Min_SOC_strg{UStorage} >=0;
param Max_SOC_strg{UStorage} >=0;
param Storage_eff{UStorage} >=0,<=1;
	
### Utility Storage inintial conditions ###
param Enrg_Strg_ini{UStorage} >=0;
	
### Demand responce parameters ###
param M_gp = 1e6;
param M_gn = 1e6;
param M_bal = 1e6;
param M_pv = 1e6;
param M_sp = 1e6;
param M_pl = 1e6;
param M_pu = -1e6;
param M_el = 1e6;
param M_eu = -1e6;
param PV_trace_DR{UBus,Time} >=0;
param Max_chrg_rate_bat{UBus} >=0;
param Max_dchrg_rate_bat{UBus} <=0;
param Min_SOC_bat{UBus} >=0;
param Max_SOC_bat{UBus} >=0;
param Bat_eff{UBus} >=0;
param alpha{UBus} >=0;
	
### Demand responce initial conditions ###
param Engy_bat_ini{UBus} >=0;
	
### Generator Decision Variables ###
var Status_var {g in UGen,Time} integer >=0,<=Units[g];
var S_Up_var {UGen,Time} integer >=0;
var S_Down_var {UGen,Time} integer >=0;
var Pwr_Gen_var {UGen,Time} >=0;
	
### Interconnector Decision Variables ###
var Pwr_line_var {ULine,Time};


### Node Angle Decision Variables ###
var Angle_line_var {UBus,Time};


### Type3 Generators variables ###
var Enrg_TES_var{G_T3,Time} >=0;
var GenT3_Rsv_var{G_T3,Time} >=0;
var Pwr_Spill_var{G_T3,Time} >=0;
	
### Utility Storage decision variable ###
var Pwr_chrg_Strg_var {UStorage,Time} >=0;
var Pwr_dchrg_Strg_var {UStorage,Time} >=0;
var Enrg_Strg_var {UStorage,Time} >=0;
	
### Demand responce decision variables ###
var Pwr_pgp_var {UBus,Time} >=0;
var Pwr_pgn_var {UBus,Time} >=0;
var Pwr_bal_var {UBus,Time} >=0;
var Pwr_pv_var {UBus,Time} >=0;
var Pwr_sp_var {UBus,Time} >=0;
var Engy_bat_var {UBus,Time} >=0;
var Pwr_bat_var {UBus,Time};
	
### Slackness Variables ###
var lambda_pg_var {UBus,Time} ;
var lambda_pb_var {UBus,Time} ;
var lambda_pv_var {UBus,Time} ;
var lambda_e_var {UBus,Time} ;
var mu_gp_var {UBus,Time} >=0;
var mu_gn_var {UBus,Time} >=0;
var mu_pb_var {UBus,Time} >=0;
var mu_pl_var {UBus,Time} >=0;
var mu_pu_var {UBus,Time} >=0;
var mu_el_var {UBus,Time} >=0;
var mu_eu_var {UBus,Time} >=0;
var mu_pv_var {UBus,Time} >=0;
var mu_sp_var {UBus,Time} >=0;
	
### Orthognal maintaining Variables ###
var b_gp_var {UBus,Time} binary;
var b_gn_var {UBus,Time} binary;
var b_bal_var {UBus,Time} binary;
var b_pv_var {UBus,Time} binary;
var b_sp_var {UBus,Time} binary;
var b_pl_var {UBus,Time} binary;
var b_pu_var {UBus,Time} binary;
var b_el_var {UBus,Time} binary;
var b_eu_var {UBus,Time} binary;


### OBJECTIVE FUNCTION ###
minimize total_cost: sum {t in Time} sum {g in UGen}(C_Fix[g]*Status_var[g,t]
 + C_Su[g]*S_Up_var[g,t] + C_Sd[g]*S_Down_var[g,t] + C_Var[g]*Pwr_Gen_var[g,t] );


### Balance Constraint ###
subject to Balance {n in UBus, t in Time}: sum{(g,n) in Gen_Bus_links} Pwr_Gen_var[g,t]
 + sum{(l1,n) in Line_end1_Bus_links}(Pwr_line_var[l1,t]) 
== Csm_Demand[n,t] + Loss_factor*Csm_Demand[n,t] 
 + sum{(l2,n) in Line_end2_Bus_links}(Pwr_line_var[l2,t])
 + sum{(s,n) in Storage_Bus_links}(Pwr_chrg_Strg_var[s,t] - Pwr_dchrg_Strg_var[s,t])
 +  Pwr_pgp_var[n,t] + Loss_factor*Pwr_pgp_var[n,t]- Pwr_pgn_var[n,t] + Loss_factor*Pwr_pgn_var[n,t];


### Active Power Reserve Constraint ### (TODO: Need to add to model)
subject to Power_Reserve {r in URegion, t in Time}: sum{(g,r) in GenT1_Region_links} Status_var[g,t]*Max_pwr[g]
 - sum{(g,r) in GenT1_Region_links} Pwr_Gen_var[g,t] 
>= sum{(n,r) in Bus_Region_links} PReserve_factor*Csm_Demand[n,t]
 - sum{(g,r) in GenT3_Region_links} GenT3_Rsv_var[g,t]
 + sum{(n,r) in Bus_Region_links} PReserve_factor*Pwr_pgp_var[n,t];


### Stable Limit of Generators Constraints ###
subject to Gen_max_pwr {g in G_Syn,t in Time}: Pwr_Gen_var[g,t] <= Max_pwr[g]*Status_var[g,t];
subject to Gen_min_pwr {g in G_Syn,t in Time}: Min_pwr[g]*Status_var[g,t] <= Pwr_Gen_var[g,t];
	
### Integer variable linking Constraint ###
subject to On_Off {g in G_Syn,t in 2..T}: S_Up_var[g,t] - S_Down_var[g,t] == Status_var[g,t] - Status_var[g,t-1];
subject to On_Off_initial {g in G_Syn}: S_Up_var[g,1] - S_Down_var[g,1] == Status_var[g,1] - Status_ini[g];
	
### Generator Ramping Constraints ### 
subject to ramp_up {g in G_Syn, t in 2..T}:Ramp_up[g]<Max_pwr[g] ==> Pwr_Gen_var[g,t] - Pwr_Gen_var[g,t-1] <= Status_var[g,t]*Ramp_up[g];
subject to ramp_up_initial {g in G_Syn}:Ramp_up[g]<Max_pwr[g] ==> Pwr_Gen_var[g,1] - Pwr_Gen_ini[g] <= Status_var[g,1]*Ramp_up[g];
subject to ramp_down {g in G_Syn, t in 2..T}:Ramp_down[g]<Max_pwr[g] ==> Pwr_Gen_var[g,t-1] - Pwr_Gen_var[g,t] <= Status_var[g,t-1]*Ramp_down[g];
subject to ramp_down_initial {g in G_Syn}:Ramp_down[g]<Max_pwr[g] ==> Pwr_Gen_ini[g] - Pwr_Gen_var[g,1] <= Status_ini[g]*Ramp_down[g];
	
### Generator Minimum Up/Down Time Constraints ###
subject to min_up_Time {g in G_Syn, t in MUT[g]..T}:MUT[g]>1 ==> Status_var[g,t]
 >= sum{t1 in 0..MUT[g]-1} S_Up_var[g,t-t1]  ;
subject to min_up_Time_ini {g in G_Syn, t in 1..MUT[g]-1}:MUT[g]>1 ==> Status_var[g,t]
 >= sum{t1 in 0..t-1} S_Up_var[g,t-t1] + MUT_ini[g,t] ;
	
subject to min_down_Time {g in G_Syn, t in MDT[g]..T}:MDT[g]>1 ==> Status_var[g,t]
 <= Units[g] - sum{t1 in 0..MDT[g]-1} S_Down_var[g,t-t1] ;
subject to min_down_Time_ini {g in G_Syn, t in 1..MDT[g]-1}:MDT[g]>1 ==> Status_var[g,t]
 <= Units[g] - sum{t1 in 0..t-1} S_Down_var[g,t-t1] - MDT_ini[g,t] ;


### Maximum limit on ON units ###
subject to max_ONunits {g in UGen, t in Time}:
Status_var[g,t] <= Units[g];
### Thermal limits of interconnect Constraints ###
subject to thermal_limit_ub {l in ULine, t in Time}: Pwr_line_var [l,t] <= ThrmLim[l];
subject to thermal_limit_lb {l in ULine, t in Time}: -ThrmLim[l] <= Pwr_line_var[l,t] ;
	
### AC line angle stablility ###
subject to angle_limit {l in ULine, t in Time}: Pwr_line_var[l,t] == Susceptance[l]*
 (sum{(l,n1) in Line_end1_Bus_links} Angle_line_var[n1,t]- sum{(l,n2) in Line_end2_Bus_links} Angle_line_var[n2,t]);


### Type2 Power Limit ###
subject to Resource_availability_T2 {g in G_T2, t in Time}: Pwr_Gen_var[g,t] <= Status_var[g,t]*Resource_trace_T2[g,t];


subject to G_T2_min_pwr {g in G_T2, t in Time}: Status_var[g,t]*Min_pwr[g]  <= Pwr_Gen_var[g,t];


### Type3 Generators Power Limit ###
subject to TES_SOC {g in G_T3, t in 2..T}: Enrg_TES_var[g,t] == TES_eff[g]*Enrg_TES_var[g,t-1] + Resource_trace_T3[g,t] - Pwr_Gen_var[g,t] - Pwr_Spill_var[g,t];
subject to TES_SOC_ini {g in G_T3}: Enrg_TES_var[g,1] == TES_eff[g]*Enrg_TES_ini[g] + Resource_trace_T3[g,1] - Pwr_Gen_var[g,1] - Pwr_Spill_var[g,1];
	
### Type3 Generators Active Power Reserve Limits ###
### Reserve limited by Generation ###
subject to GenT3_Rsv_power_limit {g in G_T3, t in Time}: GenT3_Rsv_var[g,t] <= Status_var[g,t]*Max_pwr[g]-Pwr_Gen_var[g,t];
### Reserve limited by Storage ###
subject to GenT3_Rsv_energy_limit {g in G_T3, t in Time}: GenT3_Rsv_var[g,t] <= Enrg_TES_var[g,t]-Pwr_Gen_var[g,t];
	
### CST TES SOC Limits ###
subject to Min_TES_SOC {g in G_T3, t in Time}: Enrg_TES_var [g,t] >= Min_SOC_TES[g];
subject to Max_TES_SOC {g in G_T3, t in Time}: Enrg_TES_var [g,t] <= Max_SOC_TES[g];


### Utility Storage Energy Balance Constraint ###
subject to Storage_energy_balance {s in UStorage, t in 2..T}: Enrg_Strg_var [s,t] 
= Storage_eff[s]*Enrg_Strg_var [s,t-1] + Pwr_chrg_Strg_var [s,t] - Pwr_dchrg_Strg_var [s,t];
subject to Storage_energy_balance_Initial {s in UStorage}: Enrg_Strg_var [s,1] 
= Storage_eff[s]*Enrg_Strg_ini[s] + Pwr_chrg_Strg_var [s,1] - Pwr_dchrg_Strg_var [s,1];
	
### Charge/Discharge rate Constraints ###
subject to Charge_rate_Storage {s in UStorage, t in Time}:  Pwr_chrg_Strg_var [s,t]  <= Chrg_rate_strg[s];
subject to Dcharge_rate_Storage {s in UStorage, t in Time}:  Pwr_dchrg_Strg_var [s,t]  <= Dchrg_rate_strg[s];
	
### Storage SOC Constraints ###
subject to Min_SOC_Strg {s in UStorage, t in Time}: Enrg_Strg_var [s,t] >= Min_SOC_strg[s];
subject to Max_SOC_Strg {s in UStorage, t in Time}: Enrg_Strg_var [s,t] <= Max_SOC_strg[s];


### DR Equality Constraints ###
## KKT Constraints ##
subject to KKT_pgp {p in UBus, t in Time}: lambda_pg_var[p,t] - mu_gp_var[p,t]  == -1;
subject to KKT_fdin {p in UBus, t in Time}: - lambda_pg_var[p,t] - mu_gn_var[p,t]  == alpha[p];
subject to KKT_pbat {p in UBus, t in Time}: -lambda_pb_var[p,t] - lambda_e_var[p,t] - mu_pl_var[p,t] + mu_pu_var[p,t]  == 0;
subject to KKT_ppv {p in UBus, t in Time}: lambda_pg_var[p,t] + lambda_pv_var[p,t] - mu_pv_var[p,t] == 0;
subject to KKT_pspill {p in UBus, t in Time}: lambda_pv_var[p,t] - mu_sp_var[p,t] == 0;
subject to KKT_bald {p in UBus, t in Time}: -lambda_pg_var[p,t] + lambda_pb_var[p,t] - mu_pb_var[p,t]  == 0;
subject to KKT_ebat {p in UBus, t in 1..(T-1)}: lambda_e_var[p,t] - Bat_eff[p]*lambda_e_var[p,t] - mu_el_var[p,t] + mu_eu_var[p,t] == 0;
	
## System Constraints ##
subject to Grid_bus_bal {p in UBus, t in Time}: Pwr_pgp_var[p,t] + Pwr_pv_var[p,t] - Pwr_pgn_var[p,t] - Pwr_bal_var[p,t] == 0;
subject to Load_bus_bal {p in UBus, t in Time}: Pwr_bal_var[p,t] - Pwr_bat_var[p,t]  == Psm_Demand[p,t];
subject to PV_bus_bal {p in UBus, t in Time}: Pwr_pv_var[p,t] + Pwr_sp_var[p,t]  == PV_trace_DR[p,t];
subject to Battery_SOC {p in UBus, t in 2..T}:  Engy_bat_var[p,t] - Bat_eff[p]*Engy_bat_var[p,t-1] - Pwr_bat_var[p,t]  == 0 ;
subject to Battery_SOC_Initial {p in UBus}:  Engy_bat_var[p,1] - Bat_eff[p]*Engy_bat_ini[p] - Pwr_bat_var[p,1]  == 0 ;


## Inequality Constraints ##
## Orthogonal Constraints ##
subject to mu_gp_perp_pgp_A {p in UBus, t in Time}:
		 Pwr_pgp_var[p,t] <= M_gp*b_gp_var[p,t];
subject to mu_gp_perp_pgp_B {p in UBus, t in Time}:
		 mu_gp_var[p,t] <= M_gp * (1 - b_gp_var[p,t]) ;
	
subject to mu_gn_perp_pgn_A {p in UBus, t in Time}:
		 Pwr_pgn_var[p,t] <= M_gn*b_gn_var[p,t];
subject to mu_gn_perp_pgn_B {p in UBus, t in Time}:
		 mu_gn_var[p,t] <= M_gn * (1 - b_gn_var[p,t]) ;
	
subject to mu_pb_perp_bal_A {p in UBus, t in Time}:
		 Pwr_bal_var[p,t] <= M_bal*b_bal_var[p,t];
subject to mu_pb_perp_bal_B {p in UBus, t in Time}:
		 mu_pb_var[p,t] <= M_bal * (1 - b_bal_var[p,t]) ;
	
subject to mu_pv_perp_ppv_A {p in UBus, t in Time}:
		 Pwr_pv_var[p,t] <= M_pv*b_pv_var[p,t];
subject to mu_pv_perp_ppv_B {p in UBus, t in Time}:
		 mu_pv_var[p,t] <= M_pv * (1 - b_pv_var[p,t]) ;
	
subject to mu_sp_perp_psp_A {p in UBus, t in Time}:
		 Pwr_sp_var[p,t] <= M_sp*b_sp_var[p,t];
subject to mu_sp_perp_psp_B {p in UBus, t in Time}:
		 mu_sp_var[p,t] <= M_sp * (1 - b_sp_var[p,t]) ;
	
subject to mu_pl_perp_pb_A {p in UBus, t in Time}:
		 Pwr_bat_var[p,t] <= M_pl*b_pl_var[p,t];
subject to mu_pl_perp_pb_B {p in UBus, t in Time}:
		 mu_pl_var[p,t] <= M_pl * (1 - b_pl_var[p,t]) ;
	
subject to mu_pl_perp_pb_C {p in UBus, t in Time}:
		 Pwr_bat_var[p,t] >= Max_dchrg_rate_bat[p] ;
	
subject to mu_pu_perp_pb_A {p in UBus, t in Time}:
		 Pwr_bat_var[p,t] >= M_pu*b_pu_var[p,t];
subject to mu_pu_perp_pb_B {p in UBus, t in Time}:
		 mu_pu_var[p,t] <= M_pu * (1 - b_pu_var[p,t]) ;
	
subject to mu_pu_perp_pb_C {p in UBus, t in Time}:
		 Pwr_bat_var[p,t] <= Max_chrg_rate_bat[p] ;
	
subject to mu_el_perp_eb_A {p in UBus, t in Time}:
		 Engy_bat_var[p,t] <= M_el*b_el_var[p,t];
subject to mu_el_perp_eb_B {p in UBus, t in Time}:
		 mu_el_var[p,t] <= M_el * (1 - b_el_var[p,t]) ;
	
subject to mu_el_perp_eb_C {p in UBus, t in Time}:
		 Engy_bat_var[p,t] >= Min_SOC_bat[p] ;
	
subject to mu_eu_perp_eb_A {p in UBus, t in Time}:
		 Engy_bat_var[p,t] >= M_eu*b_eu_var[p,t];
subject to mu_eu_perp_eb_B {p in UBus, t in Time}:
		 mu_eu_var[p,t] <= M_eu * (1 - b_eu_var[p,t]) ;
	
subject to mu_eu_perp_eb_C {p in UBus, t in Time}:
		 Engy_bat_var[p,t] <= Max_SOC_bat[p] ;
	
