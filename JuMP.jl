using JuMP, GLPK, LinearAlgebra, DataFrames
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
c_w = 50;
# Total demand
d = 1500;
# Wind forecast
w_f = 200;

# In this cell we create function solve_ed, which solves the economic dispatch problem for a given set of input parameters.
function solve_ed(g_max, g_min, c_g, c_w, d, w_f)
    #Define the economic dispatch (ED) model
    ed = Model(GLPK.Optimizer)
    
    # Define decision variables    
    @variable(ed, 0 <= g[i = 1:2] <= g_max[i]) # power output of generators
    @variable(ed, 0 <= w <= w_f) # wind power injection

    # Define the objective function
    @objective(ed, Min, dot(c_g, g) + c_w * w)

    # Define the constraint on the maximum and minimum power output of each generator
    @constraint(ed, [i = 1:2], g[i] <= g_max[i]) #maximum
    @constraint(ed, [i = 1:2], g[i] >= g_min[i]) #minimum

    # Define the constraint on the wind power injection
    @constraint(ed, w <= w_f)

    # Define the power balance constraint
    @constraint(ed, sum(g) + w == d)

    # Solve statement
    optimize!(ed)
    
    # return the optimal value of the objective function and its minimizers
    return value.(g), value(w), w_f - value(w), objective_value(ed)
end

# Solve the economic dispatch problem
(g_opt, w_opt, ws_opt, obj) = solve_ed(g_max, g_min, c_g, c_w, d, w_f);

println("\n")
println("Dispatch of Generators: ", g_opt, " MW")
println("Dispatch of Wind: ", w_opt, " MW")
println("Wind spillage: ", w_f - w_opt, " MW") 
println("\n")
println("Total cost: ", obj, "\$")