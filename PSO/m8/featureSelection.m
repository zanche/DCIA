function [trainSet, testSet, numDim] = featureSelection(trainSet, trainTargets, testSet)
% Feature Selection with Competitive Swarm Optimization.
%
%   This is a wrapper feature selection method, which finds through a
%   search algorithm the best set of attributes. This best set returns the
%   best value of fitness, which is the best performance of classification.
%   In this function the fitness is calculed as AUCarea, after training set
%   classification with the selected subset of attributes.

    numDim = size(trainSet, 2); % There is no need for it to be passed in the function call
    % Memory will store all searched solutions, and in the last column it
    % holds solution's fitness
    memory = zeros(1, numDim+1);
    % Swarm size
    N = 100;
    % Algorithm parameters
    phi = 0.1;
    lambda = 0.5;
    
    %Initializing population
    population(N).position = zeros(1, numDim);
    population(N).velocity = zeros(1, numDim);
    population(N).fitness = 0;
    
    for i=1:N
        for d=1:numDim
            population(i).position(d) = randi(2) - 1;
            population(i).velocity = zeros(1, numDim);
            population(i).fitness = 0;
        end
        if ~ismember(population(i).position, memory(:, 1:end-1), 'rows')
            memory = [memory; population(i).position population(i).fitness];
        end
    end
    
    iter = 1;
    % For mean position calculation
    positions = zeros(N, numDim);
    
    while iter <= 200
        for i=1:N
            % In the first iteration there will be fitness calculation for
            % all population. Otherwise, fitness will only be calculated if
            % the solution is not in the memory
            if iter == 1    
                population(i).fitness = calculateFit(population(i).position, ...
                    trainSet, trainTargets);
                % Finding solution id on memory to update fitness value
                [~, id] = ismember(population(i).position, memory(:, 1:end-1), 'rows');
                memory(id, end) = population(i).fitness;
            else
                % Verifying if the current solution already exists on memory
                [exist, id] = ismember(population(i).position, memory(:, 1:end-1), 'rows');
                if exist
                    % If the solution was already searched, no fitness
                    % calculation is necessary
                    population(i).fitness = memory(id, end);
                else
                    population(i).fitness = calculateFit(population(i).position, ...
                        trainSet, trainTargets);
                    % Updating memory with new entrance
                    memory = [memory; population(i).position population(i).fitness];
                end
            end
            positions(i, :) = population(i).position;
        end
        
        % Calculating mean position of current population
        meanPosition = zeros(1, numDim);
        for d=1:numDim
            meanPosition(d) = mean(positions(d));
        end
        
        newPopulation = [];
        
        while ~isempty(population)
            selected = randperm(size(population, 2), 2);
            
            if population(selected(1)).fitness > population(selected(2)).fitness
                winner = population(selected(1));
                loser = population(selected(2));
                % Erasing selected population
                population([selected(1) selected(2)]) = [];
            else
                winner = population(selected(2));
                loser = population(selected(1));
                % Erasing selected population
                population([selected(1) selected(2)]) = [];
            end
            
            % Updating loser stats
            loser.velocity = (rand()*loser.velocity) + ...
                (rand()*(winner.position - loser.position)) + ...
                (phi*rand()*(meanPosition - loser.position));
            loser.position = loser.position + loser.velocity;
            % Ensuring binary vector
            for d=1:numDim
                if loser.position(d) > lambda
                    loser.position(d) = 1;
                else
                    loser.position(d) = 0;
                end
            end
            newPopulation = [newPopulation, winner, loser];
        end
        
        population = newPopulation;
        clear newPopulation
        
        iter = iter+1;
    end
    
    % Returning best solution find
    [~, bestId] = max(memory(:, end));
    trainSet = trainSet(:, find(memory(bestId, 1:end-1)));
    testSet = testSet(:, find(memory(bestId, 1:end-1)));
    numDim = size(trainSet, 2);
end

function fitness = calculateFit(solution, trainSet, trainTargets)

    selTrSet = trainSet(:, find(solution));
    numCls = size(unique(trainTargets), 1);
    
    % In order to calculate distance only once
    allDist = distance(transpose(selTrSet), transpose(selTrSet));
    
    mean_inner = zeros(1, numCls); std_inner = zeros(1, numCls);
    mean_outer = zeros(1, numCls); std_outer = zeros(1, numCls);
    
    for c=1:numCls
        clsIdx = find(trainTargets == c);
        
        % Inner distances
        if size(clsIdx, 1) > 1
            numPair_one = nchoosek(size(clsIdx, 1), 2);
            dist_one = zeros(1, numPair_one);
            
            pair = 1;
            for f = 1:size(clsIdx, 1) - 1
                for s = f+1:size(clsIdx, 1)
                    dist_one(pair) = allDist(clsIdx(f), clsIdx(s));
                    pair = pair+1;
                end
            end
        else
            dist_one = 0;
        end
        
        mean_inner(1, c) = mean(dist_one); std_inner(1, c) = std(dist_one);
        
        % Outer distances
        trainIdx = 1:size(trainSet, 1);
        trainIdx(clsIdx) = [];
    
        [A,B] = meshgrid(clsIdx, trainIdx);
        p = cat(2,A',B');
        pairs = reshape(p,[],2);
    
        numPair_two = size(pairs, 1);
        dist_two = zeros(1, numPair_two);
        
        pair = 1;
        for p = 1:size(pairs, 1)
            dist_two(pair) = allDist(pairs(p, 1), pairs(p, 2));
            pair = pair+1;
        end

        mean_outer(1, c) = mean(dist_two); std_outer(1, c) = std(dist_two);
        
    end
    
    % Partially pessimistic fitness
    fitness = sum((mean_outer - (std_outer/2)) - (mean_inner + (std_inner/2)));
end