using JuMP, GLPK, LinearAlgebra, DataFrames, Gurobi
# Define some input data about the test system
# Maximum power output of generators
g_max = [1000, 1000];
# Minimum power output of generators
g_min = [0, 300];
# Incremental cost of generators 
c_g = [50, 100];
# Fixed cost of generators
c_g0 = [1000, 0]
# Incremental cost of wind generators
c_w = [50, 50];
# Total demand
d = 1500;
# Wind forecast
w_f = [150, 50];

# Lost rate
lost_rate = [0.001, 0.001];
line_num = 2;
η = ones(line_num) - lost_rate;

# Max power of lines
f_max = [100, 1000];

# In this cell we create function solve_ed, which solves the economic dispatch problem for a given set of input parameters.
# function solve_ed(g_max, g_min, c_g, c_w, d, w_f, f_max)
    #Define the economic dispatch (ED) model
ed = Model(Gurobi.Optimizer)

# Extract parameters
g_num = length(g_max)
w_num = length(w_f)

# Define decision variables    
@variable(ed, 0 <= g[i = 1:g_num] <= g_max[i], Int) # power output of generators
@variable(ed, 0 <= w[i = 1:w_num] <= w_f[i]) # wind power injection
@variable(ed, x >= 0)


# Define the objective function
@objective(ed, Min, dot(c_g, g) + dot(c_w, w))

# Define the constraint on the maximum and minimum power output of each generator
@constraint(ed, con[i = 1:g_num], g[i] <= g_max[i]) #maximum
@constraint(ed, [i = 1:g_num], g[i] >= g_min[i]) #minimum

# Define the constraint on the wind power injection
@constraint(ed, [i = 1:w_num], w[i] <= w_f[i])

# Define the constraint on maximum power on each line
@variable(ed, bus_out[i = 1:3])
@constraint(ed, bus_out[1] == w[1])
@constraint(ed, bus_out[2] == bus_out[1] * η[1] + g[1] + w[2])
@constraint(ed, bus_out[3] == bus_out[2] * η[2] + g[2])
@constraint(ed, [i = 1:2], bus_out[i] <= f_max[i])




# Define the power balance constraint
# @constraint(ed, sum(g) + sum(w) == d)
@constraint(ed, power_balance, bus_out[3] == d)

# Solve statement
optimize!(ed)

# return the optimal value of the objective function and its minimizersob
# return value.(g), value.(w), w_f - value.(w), objective_value(ed)
# end

# Solve the economic dispatch problem
(g_opt, w_opt, ws_opt, obj) = (value.(g), value.(w), w_f - value.(w), objective_value(ed))

println("\n")
println("Dispatch of Generators: $(g_opt) MW")
println("Dispatch of Wind: $(w_opt) MW")
println("Wind spillage: $(w_f - w_opt) MW") 
println("\n")
println("Total cost: $(obj)")