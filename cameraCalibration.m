%% cameraCalibration.m
% 
% This script assumes you followed a protocol for data acquisition as
% described in Huang et al. (https://doi.org/10.1038/Nmeth.2488), i.e. you
% recorded a stack of dark frames and a couple of stacks with uniform
% intensity at different intensity levels.
% 
% The camera offset is estimated as the mean of the dark frames. The
% read noise is the standard deviation of the dark frames. The variance
% increases with higher illumination intensities. The gain is the slope of
% the variance (minus the variance of the dark frames) versus the intensity
% (minus the offset).
% 
% Some comments:
%  - the script only reads one frame at a time into memory
%  - if you acquired long stacks and they got cut up into substacks by your
%    acquisition software (e.g. dark_0.tif, dark_1.tif, dark_2.tif ...),
%    the code will automatically group them

clear all; close all; clc

%% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Parameters

% path to the folder containing the calibration stacks
directory = 'E:\data\PolCam manuscript\20210129_SYTOX orange on glass\metadata\camera calibration';

% name of the dark stack without extension or suffix (e.g. 'dark' if the
% is called dark.tif, or if the are multiple substacks dark_0.tif, dark_1.tif, dark_2.tif ...)
dark_id   = 'blanks';

% list of the names of the bright stacks without extension or suffix (like
% above), ordered from dimmest to brightest
power_ids = {'int1','int2','int3','int4','int5','int6'};



%% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

disp('+++ Camera calibration +++'); disp(' ')

% make output folder
outputdir = fullfile(directory,'calibration results');
if ~exist(outputdir,'dir'); mkdir(outputdir); end

% estimate offset
disp('Calculating offset...')
offset = calculateOffset(dark_id,directory);
figure;
set(0,'DefaultAxesTitleFontWeight','normal');
subplot(2,4,[1,2,5,6]); imshow(offset,[]); colorbar; title('Offset')
subplot(2,4,[3,4]); histogram(offset,'edgeColor','none','faceColor','k'); xlabel('Offset'); ylabel('Occurence')
subplot(2,4,[7,8]); histogram(offset,'edgeColor','none','faceColor','k'); xlabel('Offset'); ylabel('Occurence (log scale)'); set(gca,'Yscale','log')
set(gcf,'position',[100,100,1400,500]);
savefig(fullfile(outputdir,'offset.fig'))


%%

% estimate dark variance
disp('Calculating variance...')
variance = calculateVariance(offset,dark_id,directory);
figure;
set(0,'DefaultAxesTitleFontWeight','normal');
subplot(2,4,[1,2,5,6]); imshow(variance,[]); colorbar; title('Variance')
subplot(2,4,[3,4]); histogram(variance,'edgeColor','none','faceColor','k'); xlabel('Variance'); ylabel('Occurence')
subplot(2,4,[7,8]); histogram(variance,'edgeColor','none','faceColor','k'); xlabel('Variance'); ylabel('Occurence (log scale)'); set(gca,'Yscale','log')
set(gcf,'position',[100,100,1400,500]);
savefig(fullfile(outputdir,'variance.fig'))

% estimate gain
disp('Calculating gain...')
numPowers = length(power_ids);
offset_powers   = zeros(size(offset,1),size(offset,2),numPowers);
variance_powers = zeros(size(offset,1),size(offset,2),numPowers);
for i=1:numPowers
    offset_powers(:,:,i)   = calculateOffset(string(power_ids(i)),directory);
    variance_powers(:,:,i) = calculateVariance(offset_powers(:,:,i),string(power_ids(i)),directory);
end
A = variance_powers - repmat(variance,1,1,numPowers);
B = offset_powers - repmat(offset,1,1,numPowers);
gain = zeros(size(offset));
for i=1:size(A,1)
    for j=1:size(A,2)
        Ai = A(i,j,:); Ai = Ai(:)';
        Bi = B(i,j,:); Bi = Bi(:)';
        gain(i,j) = pinv(Bi*(Bi'))*Bi*(Ai');
    end
end
figure;
set(0,'DefaultAxesTitleFontWeight','normal');
subplot(2,4,[1,2,5,6]); imshow(gain,[]); colorbar; title('Gain')
subplot(2,4,[3,4]); histogram(gain,'edgeColor','none','faceColor','k'); xlabel('Gain'); ylabel('Occurence')
subplot(2,4,[7,8]); histogram(gain,'edgeColor','none','faceColor','k'); xlabel('Gain'); ylabel('Occurence (log scale)'); set(gca,'Yscale','log')
set(gcf,'position',[100,100,1400,500]);
savefig(fullfile(outputdir,'gain.fig'))

% Plot regression figure
avgCorrectedVariances   = nanmean(A,1:2); avgCorrectedVariances = avgCorrectedVariances(:);
avgCorrectedIntensities = nanmean(B,1:2); avgCorrectedIntensities = avgCorrectedIntensities(:);
errorX = nanstd(B,0,1:2); errorX = errorX(:);
errorY = nanstd(A,0,1:2); errorY = errorY(:);
figure;
errorbar(avgCorrectedIntensities,avgCorrectedVariances,errorY,errorY,errorX,errorX,'ko'); hold on
plot(avgCorrectedIntensities,avgCorrectedIntensities*nanmean(gain,'all'),'-k')
xlabel('intensity_i - dark');
ylabel('\sigma^2(intensity_i) - \sigma^2(dark)');
legend('Data','Linear fit ','Location','northwest')
axis equal; grid on
xlim([0,1.1*max(avgCorrectedVariances(end),avgCorrectedIntensities(end))])
ylim([0,1.1*max(avgCorrectedVariances(end),avgCorrectedIntensities(end))])
set(0,'DefaultAxesTitleFontWeight','normal');
title({'The slope is the average gain,',sprintf('g = %.3f +- %.3f',nanmean(gain(:)),nanstd(gain(:)))})
set(gcf,'position',[100,100,500,500]); set(gca,'fontsize',10)
savefig(fullfile(outputdir,'gain_regression.fig'))


%% Save results

% Print results to command window
fprintf('\nThe average offset   is: %.3f +- %.3f ADU counts\n',nanmean(offset(:)),nanstd(offset(:)))                                   
fprintf('The average variance is: %.3f +- %.3f ADU counts\n',nanmean(variance(:)),nanstd(variance(:)))                                   
fprintf('The average gain     is: %.3f +- %.3f ADU counts/photon\n',nanmean(gain(:)),nanstd(gain(:)))                                   
fprintf('* ADU = analog-to-digital unit\n\n')                                   

results = struct;
results.offset_map   = offset;
results.variance_map = variance;
results.gain_map     = gain;
results.offset   = nanmean(offset,'all');
results.variance = nanmean(variance,'all');
results.gain     = nanmean(gain,'all');

save(fullfile(outputdir,'results.mat'),'results');

disp('Results saved in "'+string(outputdir)+'"')
disp('  1. pixel-dependent offset, variance and gain maps')
disp('  2. average offset, variance and gain')
disp('  3. regression curve used for estimating gain')


%% Functions

function offset = calculateOffset(id,directory)
% Get list of tif files that are dark frames (i.e. have 'dark in their name')
filelist = dir(fullfile(directory,string(id)+'*.tif'));
numFiles = length(filelist);
disp('  '+string(numFiles)+' file(s) found with name containing id "'+string(id)+'"');
% Calculate the mean of all the dark frames
info   = imfinfo(fullfile(directory,filelist(1).name));
width  = info(1).Width;
height = info(1).Height;
framesCounter = 0;
offset = zeros(height,width);
for i=1:numFiles
    info = imfinfo(fullfile(directory,filelist(i).name));
    frames = size(info,1);
    for j=1:frames
        frame = double(imread(fullfile(directory,filelist(i).name),j));
        offset = offset + frame;
    end
    framesCounter = framesCounter + frames;
end
offset = offset/framesCounter;
end

function variance = calculateVariance(offset,id,directory)
% Get list of tif files that are dark frames (i.e. have 'dark in their name')
filelist = dir(fullfile(directory,string(id)+'*.tif'));
numFiles = length(filelist);
offsetSquared = offset.*offset;
framesCounter = 0;
variance = zeros(size(offset));
for i=1:numFiles
    info = imfinfo(fullfile(directory,filelist(i).name));
    frames = size(info,1);
    for j=1:frames
        frame = double(imread(fullfile(directory,filelist(i).name),j));
        variance = variance + (frame.*frame - offsetSquared);
    end
    framesCounter = framesCounter + frames;
end
variance = variance/framesCounter;
end