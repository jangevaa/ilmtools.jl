using DataFrames

function event_db_fun(pop_db)
"""
Generate an event database, where all individuals are suscpetible at time 0
"""
  DataFrame(ind_id = pop_db[:ind_id], s = zeros(size(pop_db)[1]), i = nans(size(pop_db)[1]), r = nans(size(pop_db)[1]))
end

function random_infect(event_db, n, time)
"""
Randomly infect `n` individuals at `time`. At least one random infection is required
at the beginning of a simulation
"""
  event_db[sample(event_db[:ind_id], n), 3] = time
end

function find_susceptible_fun(event_db, time)
"""
Find individuals which have not been infected prior to `time`
"""
  susceptible_index = falses(size(event_db)[1])
  for i = 1:length(susceptible_index)
    susceptible_index[i] = isnan(event_db[i,3]) || event_db[i,3] >= time
  end
  susceptible_index
end

function find_infectious_fun(event_db, time)
"""
Find individuals which have been infected prior to `time`, but have not recovered
"""
  infectious_index = falses(size(event_db)[1])
  for i = 1:length(infectious_index)
    infectious_index[i] = event_db[i,3] < time && ((isnan(event_db[i,4])) || (time <= event_db[i,4]))
  end
  infectious_index
end




function find_infectious_fun(event_db, time, when)
"""
Find individuals which have been infected, but have not recovered prior to, or at `time`
"""
  if when =='now'
    event_db[(event_db[:time] .== time) & (event_db[:newstatus] .== 'i'),1]
  end
  if when =='prior'
    infected = event_db[(event_db[:time] .< time) & (event_db[:newstatus] .== 'i'),1]
    recovered = event_db[(event_db[:time] .< time) & (event_db[:newstatus] .== 'r'),1]
    if length(recovered) > 0
      step1 = trues(length(infected))
      for i = 1:length(infected)
        step1[i] = any(recovered .== infected[i]) == false
      end
      infected[step1]
    else
      infected
    end
  end
end

function find_recovered_fun(event_db, time, when)
"""
Find individuals which have recovered at, or prior to `time`
"""
  if when == 'now'
    event_db[(event_db[:time] .== time) & (event_db[:newstatus] .== 'r'),1]
  end
  if when == 'prior'
    event_db[(event_db[:time] .< time) & (event_db[:newstatus] .== 'r'),1]
  end
end

function find_recovery_times(event_db)
"""
Determine recovery times for individuals
"""
  recovered_db=event_db[event_db[:newstatus] .== 'r', :]
  infected_db=event_db[event_db[:newstatus] .== 'i', :]
  recovery_times = zeros(size(recovered_db)[1])
  for i = 1:length(recovery_times)
    recovery_times[i] = recovered_db[i,:time] - infected_db[infected_db[:ind_id] .== recovered_db[i,:ind_id],:time][1]
  end
  recovery_times
end

function infect_prob_fun(distance_mat, infectious, susceptible, alpha, beta)
"""
Determine infection probabilities for all susceptible individuals
"""
  1 .- exp(-alpha .* sum(distance_mat[susceptible, infectious].^-beta, 2))
end

function infect_fun(distance_mat, event_db, time, alpha, beta)
"""
Propagate infection through population according to `alpha` and `beta`
"""
  susceptible = find_susceptible_fun(event_db, time)
  infect_probs=infect_prob_fun(distance_mat, find_infectious_fun(event_db, time), susceptible, alpha, beta)
  infected = falses(length(susceptible))
  for i in 1:length(susceptible)
    infected[i] = rand() < infect_probs[i,1]
  end
  append!(event_db, DataFrame(ind_id = susceptible[infected], newstatus = rep('i', sum(infected)), time = rep(time, sum(infected))))
end

function recover_fun(event_db, time, gamma_inverse)
"""
Recover individuals following a geometric distribution with p = `gamma_inverse`
"""
  infectious = find_infectious_fun(event_db, time)
  recovered = falses(length(infectious))
  for i = 1:length(infectious)
    recovered[i] = rand() < gamma_inverse
  end
  append!(event_db, DataFrame(ind_id = infectious[recovered], newstatus = rep('r', sum(recovered)), time = rep(time, sum(recovered))))
end

