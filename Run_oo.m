% Rewrite the Run file using the CellData classes
% Purpose:
%   create a simple and intuitive interface for test driving new algorithms
%   The gory details of working with any of the fcs data should be
%   abstracted away

% Formalize this as the control script
clear all; clc;
% Add all of the external libraries in the directory
currentFolder = pwd;
addpath(genpath(currentFolder));

%% %%%%% DATA PRE-PROCESSING %%%%%

% Script Variables 
cell_data_array_all = []; % array of pointers to all CellData objects created

% Create array of all fcs files as CellData objects
D=dir;
fnames = {D.name};
for i = 1:length(fnames)
    if(CellData.isReadable(fnames{i}))
        cell_data_array_all = [cell_data_array_all, CellData(fnames{i})]; %#ok<AGROW>
    end
end

%% DATA PROCESSING

%%%%% VARIABLE INITIALIZATION %%%%%

% Cell Categories - definitions per the biologists
StemCells = Set({'HSC', 'MPP', 'CMP', 'GMP', 'MEP'});
BCells = Set({'Plasma cell', 'Pre-B I', 'Pre-B II', 'Immature B', 'Mature CD38lo B', 'Mature CD38mid B'});
TCells = Set({'Mature CD4+ T', 'Mature CD8+ T', 'Naive CD4+ T', 'Naive CD8+ T'});
NK = Set({'NK'});
pDC = Set({'Plasmacytoid DC'});
Monocytes = Set({'CD11b- Monocyte', 'CD11bhi Monocyte', 'CD11bmid Monocyte'});

% User Variables
whichCellTypes = Monocytes & pDC & NK; 
% whichCellTypes = TCells & BCells;
numRandTrainExPerFile = 400; % 400 seems optimal for tsne 
hueSensitivity = .75;
whichStimLevels = Set({'Basal'}); % Either 'Basal' or 'PV04', can contain both
useSurfaceProteinsOnly = true;


%%%%% DATA PARSING %%%%%

% Keep the CellData objects whose cell_type is contained in the
% whichCellTypes variable
removeIndicies = [];
for i = 1:length(cell_data_array_all)
    ct = cell_data_array_all(i).cell_types; % will be a single string since no CellData objects have seen merger
    st = cell_data_array_all(i).cell_stimulation_levels; % also a string
    if(~whichCellTypes.contains(ct) || ~whichStimLevels.contains(st))
        removeIndicies = [removeIndicies, i]; %#ok<AGROW>
    end
end
cell_data_array = cell_data_array_all;
cell_data_array(removeIndicies) = [];

% Create single CellData object out of desired data
DesiredCells = CellData.merge(cell_data_array, numRandTrainExPerFile);

% Obtain data matrix and pre-process with arcsinh
if(useSurfaceProteinsOnly)
    data_stack = DesiredCells.getSurfaceProteinData();
else
    data_stack = DesiredCells.getProteinData();
end
data_stack = asinh(data_stack/5);

% Get data chunk indices - indices to the chunks of data that form the
% child object DesiredCells. Used for plotting
chunk_indices = DesiredCells.data_subset_indicies_for_merged_data;

% Get colors - may change for different algorithms
colors = zeros(length(whichCellTypes), 3); % RGB for every cell subtype
for j = 1:whichCellTypes.length()
    colors(j,:) = CellSubtype2Hue(whichCellTypes.list{j}, hueSensitivity);
end


%%%%% ALGORITHM SELECTION %%%%%

%%%%%%%%% DIMENSIONAL REDUCTION ALGORITHMS & PLOTTING %%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%% Naive Linear Methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PCA %%
display('Running PCA on Data')
[coeff,score_PCA,latent] = princomp(data_stack);
display('Plotting PCA')
plotIn3D = false;
figure('name','PCA'); hold on;
for i = 1:whichCellTypes.length()
    lb = chunk_indices(i);
    ub = chunk_indices(i+1)-1;
    if(plotIn3D)
        display('plotting 3D');
        scatter3(score_PCA(lb:ub,1),score_PCA(lb:ub,2),score_PCA(lb:ub,3), 20, colors(i,:));
    else
        % Plot scatter for PCA
        scatter(score_PCA(lb:ub,1),score_PCA(lb:ub,2), 20, colors(i,:));
        title(['PCA: N/file=' num2str(numRandTrainExPerFile)]);
    end
end
legend(whichCellTypes.list)
hold off;
drawnow

%%%%%%%%%%%%%% Non - Linear Methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% t-SNE (Max's Code) %%
% dimensionality reduction to dim = 2
% see the file alg_tsne for more details

% Want dimensionality reduction to 2
dim = 2;

% stopping criteria: number of iterations is no more than 100, runtime is
% no more than 30 seconds, and the relative tolerance in the embedding is 
% no less than 1e-3. Taken from Max's tsne example demo_swissroll.m
opts.maxit = 400; opts.runtime = 900; opts.tol = 1e-3;
opts.X0 = 1e-5*randn(size(data_stack, 1), dim);

% Run algorithm
display('Running t-SNE (Max Code) on Data');
[tsne_output, E, A, T] = alg_tsne(data_stack, dim, opts);

% Plot results
display('Plotting t-SNE (Maxs Code)')
figure('name','t-SNE: Maxs Code'); 
hold on;
for i = 1:whichCellTypes.length()
    lb = chunk_indices(i);
    ub = chunk_indices(i+1)-1;        
    scatter(tsne_output(lb:ub,1),tsne_output(lb:ub,2), 20, colors(i,:));
    title(['TSNE: iter #' num2str(length(E)), ', e=' num2str(E(end)),...
       ', t=' num2str(T(end)), ', N/file=' num2str(numRandTrainExPerFile)]);   
end
legend(whichCellTypes.list)
hold off;
drawnow

%% s-SNE %%
% dimensionality reduction to dim = 2
% see the file alg_ssne for more details

% Want dimensionality reduction to 2
dim = 2;

% stopping criteria: number of iterations is no more than 100, runtime is
% no more than 30 seconds, and the relative tolerance in the embedding is 
% no less than 1e-3. Taken from Max's tsne example demo_swissroll.m
opts.maxit = 600; opts.runtime = 900; opts.tol = 1e-3;
opts.X0 = 1e-5*randn(size(data_stack, 1), dim);

% Run algorithm
[ssne_output, E, A, T] = alg_ssne(data_stack, dim, opts);

% Plot results
figure; hold on;
for i = 1:whichCellTypes.length()
    lb = chunk_indices(i);
    ub = chunk_indices(i+1)-1;        
    scatter(ssne_output(lb:ub,1),ssne_output(lb:ub,2), 20, colors(i,:));
    title(['SSNE: iter #' num2str(length(E)), ', e=' num2str(E(end)),...
       ', t=' num2str(T(end)), ', N/file=' num2str(numRandTrainExPerFile)]);   
end
legend(whichCellTypes.list)

%% EE %%
% dimensionality reduction to dim = 2
% see the file alg_ee for more details

% Want dimensionality reduction to 2
dim = 2;

% stopping criteria: number of iterations is no more than 100, runtime is
% no more than 30 seconds, and the relative tolerance in the embedding is 
% no less than 1e-3. Taken from Max's tsne example demo_swissroll.m
opts.maxit = 100; opts.runtime = 900; opts.tol = 1e-3;
opts.X0 = 1e-5*randn(size(data_stack, 1), dim);

% Run algorithm
[ee_output, E, A, T] = alg_ee(data_stack, dim, opts);

% Plot results
figure; hold on;
for i = 1:whichCellTypes.length()
    lb = chunk_indices(i);
    ub = chunk_indices(i+1)-1;        
    scatter(ee_output(lb:ub,1),ee_output(lb:ub,2), 20, colors(i,:));
    title(['EE: iter #' num2str(length(E)), ', e=' num2str(E(end)),...
       ', t=' num2str(T(end)), ', N/file=' num2str(numRandTrainExPerFile)]);   
end
legend(whichCellTypes.list)

%% Merge select figures into 1 with subplots

% Find figures
figHandles_all = findobj('Type','figure'); % Get all
figHandles = [1 2]; % indexes to figure numbers
nrows = 1;
ncols = 2;

% Get subplot positions
nfindex = max(figHandles_all) + 1;
figure(nfindex); % Create new figure
sppos = []
for i = 1:length(figHandles)
    sppos = [sppos; get(subplot(nrows, ncols,i), 'pos')];
end

% Copy figures into subplots of new figure
new_splots = {};
for i = 1:length(figHandles)
    new_splots{end +1} = copyobj(get(figHandles(i), 'children'), nfindex);
end
for i = 1:length(figHandles)
    set(new_splots{i}, 'pos', sppos(i,:));
end

%% %%%%%%%%%%%%% ALGORITHMS FROM DR TOOLBOX %%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%% Naive Linear Methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Multidimensional Scaling

% % Run non-classical MDS on the data
% display ('Running non-classical MDS')
% dissimilarities = pdist(zscore(dataStack));
% [score_ncMDS,stress] = mdscale(dissimilarities,2,'criterion','metricstress');
% 
% % Plot the Figure for non-classical MDS
% display ('Plotting non-classical MDS Result')
% figure('name','ncMDS');
% hold on;
% for i = 1:length(whichCellTypes)
%     lb = scoreIndices(i)+1;
%     ub = scoreIndices(i+1);
%     if(plotIn3D)
%         display('plotting 3D');
%         scatter3(score_ncMDS(lb:ub,1),score_ncMDS(lb:ub,2),score_ncMDS(lb:ub,3), 20, colors(i,:));
%     else
%         % Plot scatter for PCA
%         scatter(score_ncMDS(lb:ub,1),score_ncMDS(lb:ub,2), 20, colors(i,:));
%         xlabel('p1');
%         ylabel('p2');
%         title(strcat('non-classical MDS ',expr_title));
%     end
% %     scatter(score((i-1)*400+1:400*i,1),score(i:400*i + 1,2),'filled','b');
% %     scatter(score((i-1)*400+1:400*i,1),score((i-1)*400+1:400*i,2), c(i),'filled');
% %     scatter(score(lb:ub,1),score(lb:ub,2), c(i),'filled', 'markersize', 10);
% end
% legend(whichCellTypes)
% hold off;
% drawnow
%% 

% Run ICA on the data - good for separation

%%%%%%%%%%%%%% Non - Linear Methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% ISOMAP Algorithm

% Run Isomap Algorithm on Data
display('Running Isomap on Data');
[score_isomap, mapping_isomap] = isomap(data_stack);
%ISOMAP Runs the Isomap algorithm
%
%   [mappedX, mapping] = isomap(X, no_dims, k); 

% Plot the Figure for Isomap
plotIn3D = false;
display('Plotting Isomap Result')
figure('name','Isomap');
hold on;
for i = 1:whichCellTypes.length()
    lb = chunk_indices(i);
    ub = chunk_indices(i+1)-1;
    if ub>size(score_isomap,1)
        ub=size(score_isomap,1)
    end
    if(plotIn3D)
        display('plotting 3D');
        if(size(score_isomap,2)<3)
            display('Cannot plot Isomap results in 3D - need more data - Run Isomap with no_dims of >=3');
        else
            scatter3(score_isomap(lb:ub,1),score_isomap(lb:ub,2),score_isomap(lb:ub,3), 20, colors(i,:));
        end
    else
        % Plot scatter for Isomap
        scatter(score_isomap(lb:ub,1),score_isomap(lb:ub,2), 20, colors(i,:));
        xlabel('p1');
        ylabel('p2');
        title(['Isomap: N/file=' num2str(numRandTrainExPerFile)]);
    end
end
legend(whichCellTypes.list)
hold off;
drawnow

%% Locally Linear Embedding



%%%%%%%%%%% SNE & t-SNE ALGORITHMS (take a while to converge) %%%%%%%%%%%
%% 

% % Run SNE on Data 
% display('Running SNE on Data')
% score_SNE = sne(data_stack);
% %SNE Implementation of Stochastic Neighbor Embedding
% %
% %   mappedX = sne(X, no_dims, perplexity)

% % Plot the Figure for SNE
% display('Plotting SNE Result')
% figure('name','SNE');
% hold on;
% for i = 1:length(whichCellTypes)
%     lb = scoreIndices(i)+1;
%     ub = scoreIndices(i+1);
%     if(plotIn3D)
%         display('plotting 3D');
%         if(size(score_SNE,2)<3)
%             display('Cannot plot SNE results in 3D - need more data - Run tSNE with no_dims of >=3');
%         else
%             scatter3(score_SNE(lb:ub,1),score_SNE(lb:ub,2),score_SNE(lb:ub,3), 20, colors(i,:));
%         end
%     else
%         % Plot scatter for tSNE
%         scatter(score_SNE(lb:ub,1),score_SNE(lb:ub,2), 20, colors(i,:));
%         xlabel('p1');
%         ylabel('p2');
%         title(['SNE: N/file=' num2str(numRandTrainExPerFile)]);
%     end
% end
% legend(whichCellTypes.list)
% hold off;
% drawnow
%% 

% % Run tSNE on the data 
% display('Running t-SNE on data')
% score_tSNE = tsne(data_stack);
% %TSNE Performs symmetric t-SNE on dataset X
% %
% %   mappedX = tsne(X, labels, no_dims, initial_dims, perplexity)
% %   mappedX = tsne(X, labels, initial_solution, perplexity)

% % Plot the Figure for t-SNE
% display('Plotting t-SNE Result')
% figure('name','t-SNE');
% hold on;
% for i = 1:length(whichCellTypes)
%     lb = scoreIndices(i)+1;
%     ub = scoreIndices(i+1);
%     if(plotIn3D)
%         display('plotting 3D');
%         if(size(score_tSNE,2)<3)
%             display('Cannot plot tSNE results in 3D - need more data - Run tSNE with no_dims of >=3');
%         else
%             scatter3(score_tSNE(lb:ub,1),score_tSNE(lb:ub,2),score_tSNE(lb:ub,3), 20, colors(i,:));
%         end
%     else
%         % Plot scatter for tSNE
%         scatter(score_tSNE(lb:ub,1),score_tSNE(lb:ub,2), 20, colors(i,:));
%         xlabel('p1');
%         ylabel('p2');
%         title(['t-SNE: N/file=' num2str(numRandTrainExPerFile)]);
%     end
% end
% legend(whichCellTypes.list)
% hold off;
% drawnow

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
