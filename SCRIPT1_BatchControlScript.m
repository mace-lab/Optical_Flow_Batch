%% Main Flow Tracking Analysis Script
%  The goal of this analysis is to track actin dynamics in actin
%  fluorescence movies using Optical Flow and Crocker-Grier Least-Squares
%  Minimization Particle Tracking.

clear
% close all
clc
%% 

%% Global parameters %%

% File Detail Parameters
pxPerMicron = 9.35;%15.38;% for BW data 9.2593; %      <---- Number of pixels per micron
timeBtwFrames = 1; %         <---- Time between two frames
timeUnit = 1; %              <---- Time in seconds = 1, Time in minutes = 2;
thetaInDegrees = 0; %        <---- The angle of rotation (used to align ridges)
dataGroup = 1;
dataGroupName = 'MartinezBatch2';

% % % % % --------- Adjustable Analysis Parameters --------- % % % % % 

% 1) Changes the amount of smoothing done on the bgSubImage
% The first two entries are spatial smoothing, third entry is time smoothing
smoothSig = [12, 12, 1.5]; % set ratios as [x, x, x/4]

% 2) Changes the window size over which the optical flow vectors are calculated
% Small values - capture small waves/Large values - large waves
wSig = 4; % Sensitive parameter - associate with given resolution (obj type)

% 3,4) Changes the radii over which clusters are searched for
% Do not make minR smaller than the size of noise (2-3px minimum is suggested)
% maxR should be larger than the largest cluster you're searching for
minR = 3;
maxR = 12;

% 5,6,7) Parameters used for Crocker-Grier Particle Tracking...
% 
% clusterRad: the radius used to group together "similarly pointed"
% Optical Flow vectors
clusterRad = 2;
% peakSize: the input to "pkfnd.m" used to define the radius of a tracked
% particle and should be chosen carefully
peakSize = 15;
% trackMaxDisp: the input to "track.m" used to determine the maximum
% displacement that a particle can travel while still being tracked
trackMaxDisp = 10;

% 8) Minimum Track Length: used to eliminate tracks that are not long
% enough to be considered "real tracks"
minTrackLength = 5;

% % % % % --------- Adjustable Visual Parameters --------- % % % % % 

% Visual Flow Figure Parameters
frameNum = 10;
intGamma = 0.75;
intThresh = 0;
relGamma = 0.33;
relThreshFac = 1e-2;
magGamma = -1;
magThresh = 0;
flowSig = 1;
spacingA = 6;
spacingFacA = 72;
vecLineWidthA = 1.25;
spacingB = 6;
spacingFacB = 72;
vecLineWidthB = 1.25;
spacingC = 2;
spacingFacC = 2;
vecLineWidthC = 1;
periodicxcmap1 = parula(64);
periodicxcmap1 = circshift([flipud(periodicxcmap1); periodicxcmap1; flipud(periodicxcmap1); periodicxcmap1], size(periodicxcmap1, 1));
periodicxcmap2 = parula(16);
periodicxcmap2 = circshift([flipud(periodicxcmap2); periodicxcmap2; flipud(periodicxcmap2); periodicxcmap2], size(periodicxcmap2, 1));
outlineLineWidth = 2;

% Visual Flow Distribution Parameters
distOption = 1;   %  <------- distOption = 1 means [0, 90], distOption = 2 means [0, 360]
dataBinWidth = 5; % <------- plots will always be 2x this binWidth

% % -- All other parameters are contained in their respective functions -- % %

% Process Parameters
if timeUnit == 1
    secBtwFrames = timeBtwFrames;
elseif timeUnit == 2
    secBtwFrames = 60*timeBtwFrames;
else
    error('timeUnit not recognized');
end
thetaInRadians = thetaInDegrees*pi/180;


%% Define File paths %%

masterImport = 'D:\Michael_Shannon\MartinezMaster\PIVtestfolder_MASTER\';

D = dir(masterImport); % A is a struct ... first elements are '.' and '..' used for navigation.

for k = 3:length(D) % avoid using . and ..
    condD = D(k).name; % Get the condition subdirectory name
      condDir=[masterImport,condD];
      repD = dir(condDir); % Get the file list in the subdirectory
      idx = cellfun(@(repD)contains(repD,'output'),{repD.name}, 'Unif',0);          % True If ‘output’ Present
      repD_edited = repD(~[idx{:}]);                                          % Files Without ‘output’ In File Names
      repD = repD_edited;
      
      for j=3:length(repD)
          imageD=repD(j).name;
            %Have to define new importFolder, which is this one, each time
            importFolder=[condDir, '\', imageD, '\'];
            tifD=dir(importFolder);
            fileName=tifD(3).name;
            %Have to define new exportFolder, which is this one, each time
            exportFolder=[condDir, '\', imageD, '_output\'];
            if ~exist (exportFolder)
                mkdir (exportFolder);
            end
              
            % Set File Parameters
            fileParams.fileName = fileName;
            fileParams.dataGroup = dataGroup;
            fileParams.dataGroupName = dataGroupName;
            fileParams.importFolder = importFolder;
            fileParams.exportFolder = exportFolder;
            fileParams.pxPerMicron = pxPerMicron;
            fileParams.secBtwFrames = secBtwFrames;
            fileParams.thetaInDegrees = thetaInDegrees;
            fileParams.thetaInRadians = thetaInRadians;
            
            % Set Adjustable Analysis Parameters
            mainAnalysisParams.smoothSig = smoothSig;
            mainAnalysisParams.wSig = wSig;
            mainAnalysisParams.minR = minR;
            mainAnalysisParams.maxR = maxR;
            mainAnalysisParams.clusterRad = clusterRad;
            mainAnalysisParams.peakSize = peakSize;
            mainAnalysisParams.trackMaxDisp = trackMaxDisp;
            mainAnalysisParams.minTrackLength = minTrackLength;
            
             % Set Visual Flow Figure Parameters
            flowFigureImageParams.frameNum = frameNum;
            flowFigureImageParams.intGamma = intGamma;
            flowFigureImageParams.intThresh = intThresh;
            flowFigureImageParams.relGamma = relGamma;
            flowFigureImageParams.relThreshFac = relThreshFac;
            flowFigureImageParams.magGamma = magGamma;
            flowFigureImageParams.magThresh = magThresh;
            flowFigureImageParams.flowSig = flowSig;
            flowFigureImageParams.spacingA = spacingA;
            flowFigureImageParams.spacingFacA = spacingFacA;
            flowFigureImageParams.vecLineWidthA = vecLineWidthA;
            flowFigureImageParams.spacingB = spacingB;
            flowFigureImageParams.spacingFacB = spacingFacB;
            flowFigureImageParams.vecLineWidthB = vecLineWidthB;
            flowFigureImageParams.spacingC = spacingC;
            flowFigureImageParams.spacingFacC = spacingFacC;
            flowFigureImageParams.vecLineWidthC = vecLineWidthC;
            flowFigureImageParams.periodicxcmap1 = periodicxcmap1;
            flowFigureImageParams.periodicxcmap2 = periodicxcmap2;
            flowFigureImageParams.outlineLineWidth = outlineLineWidth;
            
               % Set Flow Distribution Parameters
            showBinWidth = dataBinWidth*2;
            flowDistParams.distOption = distOption;
            flowDistParams.dataBinWidth = dataBinWidth;
            flowDistParams.showBinWidth = showBinWidth;
            
            %% Run Analysis Script
            %  The goal of this part of the code is to generate the core files needed
            %  for the analysis of actin dynamics using Optical Flow and Crocker-Grier
            %  tracking

            % Run MainAnalysisScript


            MainAnalysisScript(fileParams, mainAnalysisParams);
            
      end
end


            




