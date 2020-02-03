function [F] = plotSessionPerformance(D)


% Limit length of washout block
blockInds = 1:8; % Corresponding to 128 trials assuming a block size of 16
if strcmp(D(end).blockNotes,'Baseline Washout')
    D(end).blockSuccessRate = D(end).blockSuccessRate(blockInds);
    D(end).blockAcquireTimeSuccessMean = D(end).blockAcquireTimeSuccessMean(blockInds);
end

% Get success code and acquire time data
successCodeBlock = [D.blockSuccessRate] * 100;
acquireTimeBlock = [D.blockAcquireTimeSuccessMean]/1000;
decTrans = cumsum([D.nBlocks]) + 0.5;
decTrans = [0.5, decTrans(1:(end-1))];

nDec = length(D);
nBlocks = length(successCodeBlock);
blockSize = D(1).blockSize;

% Get highlight block data.  This allows the average data for the entirety
% of the evaluation blocks to be plotted.
evaluationBlockMask = [D.evaluationBlock];
Deval = D(evaluationBlockMask);
evalBlockNames = {Deval.blockNotes};
nEvalBlocks = length(Deval);
aT_eval = nan(nEvalBlocks,1);
sR_eval = nan(nEvalBlocks,1);
aT_eval_ci = nan(nEvalBlocks,2);
sR_eval_ci = nan(nEvalBlocks,2);

% Loop over evaluation blocks and calculate success rate, acquisition time,
% target acquisition rate
for i = 1:length(Deval)
    sC = Deval(i).successCode;
    aT = Deval(i).acquireTime/1000;
    
    % Limit to 128 trials for the washout block
    if strcmp(evalBlockNames{i},'Baseline Washout')
        sC = sC(1:128);
        aT = aT(1:128);
    end
    
    % Calcualte mean success rate, acquisition time, and target acquisition
    % rate
    aT_eval(i) = mean(aT(logical(sC)));
    sR_eval(i) = sum(sC)/length(sC) * 100;
    
    % Estimate confidence intervals
    aT_eval_ci(i,:) = confidenceInterval(aT);
    sR_eval_ci(i,:) = confidenceInterval(sC) * 100;
end


% =========================================================================
% Setup figure
nCol = 1;
nRow = 2;
axW = 900;
axH = 175;
axSp = 10;
[fW,fH,Ax] = calcFigureSize(nRow, nCol, axW, axH, axSp);
F = figure('Position',[100 100 fW fH]);


% =========================================================================
% Plot success rate

subplotSimple(nRow, nCol, 1, 'Ax', Ax); hold on;

% Plot patches corresponding to evaluation blocks
yLim = [0 100];
plotEvaluationBlocks(D, decTrans, yLim)
plot(successCodeBlock, 'k.-', 'MarkerSize', 20);
plot(repmat(decTrans,2,1), repmat(yLim', 1, nDec), 'r--')
set(gca, ...
    'XLim', [0, nBlocks+1], ...
    'Box', 'off', ...
    'XTickLabel', [], ...
    'TickDir', 'out')
ylabel('% Success')

% Plot names
for i = 1:nDec
    text(decTrans(i), yLim(1), sprintf('D %0.2d', D(i).decoderNum), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'top', ...
        'color', 'r', ...
        'FontSize', 8)
end

% Plot average success rate for blocks
subplot('Position', ...
    [Ax.xMarg + axW/fW + Ax.xSp, Ax.yMarg + 1*(axH/fH + Ax.ySp), ...
    Ax.xSp*4, axH/fH])
hold on

for i = 1:nEvalBlocks
    colTemp = getEvalBlockColor(evalBlockNames{i});
    plot(i,sR_eval(i),'color',colTemp,'Marker','.','MarkerSize',10); hold on;
    errorbar(i,sR_eval(i),sR_eval(i) - sR_eval_ci(i,1), ...
        sR_eval_ci(i,2) - sR_eval(i),'color',colTemp)
end
set(gca, 'YLim', yLim, 'XTickLabel', [], 'YTickLabel', [])

% =========================================================================
% Plot acquire time

% Set those acquisition times where success rate is less than a pre-defined
% threshold to NaN.  The assumption here is that these acquisition times
% are invalid, as they don't adequately sample all targets.
srThresh = 50;
srMask = successCodeBlock <= srThresh;
acquireTimeBlock(srMask) = NaN;
maxAcquireTime = max(acquireTimeBlock);
maxAcquireTime = ceil(maxAcquireTime/0.5)*0.5;
acqTimeLim = [0 maxAcquireTime];
acqTimeNCLim = [1 2] + maxAcquireTime;
acquireTimeBlock(srMask) = maxAcquireTime + 1.5;

subplotSimple(nRow, nCol,2, 'Ax', Ax); hold on;
yLim = [0 ceil(max(acquireTimeBlock))];
plotEvaluationBlocks(D, decTrans, yLim)

% Plot acquisition times
acquireTimeX = find(srMask);
acquireTimeNC = acquireTimeBlock(srMask);
acquireTimeBlock(srMask) = NaN;
plot(acquireTimeBlock, 'k.-', 'MarkerSize', 20); hold on;
plot(acquireTimeX, acquireTimeNC, 'r.', 'MarkerSize', 20); hold on;

% Plot lines indicating decoder transitions
plot(repmat(decTrans,2,1), repmat(yLim',1,nDec), 'r--')
set(gca, ...
    'XLim', [0 nBlocks+1], ...
    'YLim', yLim, ...
    'box', 'off', ...
    'XTickLabel', [], ...
    'TickDir', 'out')
xlabel(sprintf('Block (%d trials)', blockSize))
ylabel('Mean Acquisition Time (s)')

% Set y-tick label for 'non-computed' (NC) blocks
set(gca,'YTick',[acqTimeLim acqTimeNCLim])
yTickLabel = {num2str(acqTimeLim(1)), num2str(acqTimeLim(2)),'NC','NC'};
set(gca,'YTickLabel', yTickLabel)

% Plot names
for i = 1:nDec
    text(decTrans(i),yLim(1), sprintf('D %0.2d',D(i).decoderNum), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'top', ...
        'color', 'r', ...
        'FontSize',8)
end

% Plot average acquisition time for evaluation blocks
subplot('Position', ...
    [Ax.xMarg + axW/fW + Ax.xSp, Ax.yMarg + 0*(axH/fH + Ax.ySp), ...
    Ax.xSp*4, axH/fH])
hold on

for i = 1:nEvalBlocks
    colTemp = getEvalBlockColor(evalBlockNames{i});
    plot(i, aT_eval(i), ...
        'color', colTemp, ...
        'Marker', '.', ...
        'MarkerSize', 10);
    hold on;
    errorbar(i, aT_eval(i), aT_eval(i) - aT_eval_ci(i,1), ...
        aT_eval_ci(i,2) - aT_eval(i), 'color', colTemp)
end
set(gca, 'YLim', yLim, 'XTickLabel', [], 'YTickLabel',[])

end % EOF

function plotEvaluationBlocks(D, decTrans, yLim)
% Plot background for evaluation blocks.

% Get all evaluation blocks to plot
evalInds = find([D.highlightBlock]);

nEvalBlocks = length(evalInds);
for i = 1:nEvalBlocks
    xOnset = decTrans(evalInds(i));
    xOffset = xOnset + D(evalInds(i)).nBlocks;
    w = xOffset - xOnset;
    h = yLim(2) - yLim(1);
    
    rectangle('Position', [xOnset yLim(1) w h],...
        'FaceColor', getEvalBlockColor(D(evalInds(i)).blockNotes))
end
end % EOF