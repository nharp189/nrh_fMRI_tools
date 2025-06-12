function [t_result, betas, t, p] = voxelwise_log_reg(DB, Y, X)

% This function is compatible with neuroimaging data in Tor Wager's CanlabCore
% format. It requires that (1) you have a database structure and (2) that
% you have an fmri_data object containing contrast indicator maps for each
% study/contrast.   
%
% Inputs:
%   DB: database object from Meta_Activation_FWE.m
%   Y: contrast indicator maps in fmri_data object
%   X: regressor design matrix
%  
% Outputs:
%   result: statistic object with t, df, and p-val in brain space
%
% Note: code dependent on CanlabCore repository (and thanks to Tor Wager for allowing
% me to pull pieces from Meta_Logistic.m).

%% index which contrasts to use, select relevant CIMs

% create index from included cons %
c = find(DB.included_cons == 1);

y = Y.get_wh_image(c);

y = y.dat;

%% PULL THIS OUT OF CODE EVENTUALLY?
% ---------------------------------------
% Set up design matrix
% names = contrast names, also output image names
% prunes DB
% ---------------------------------------

% [X,names,DB,Xi,Xinms,condf,testfield] = Meta_Logistic_Design(DB);

%% OLD - REMOVE?

% global dims
global cols
% 
% spm_defaults; defaults.analyze.flip = 0;
% doload = 0;
% 
% % get map dimensions
% dims = Y.volInfo.dim;
% 
% % set up predictor cols from design matrix
cols = size(X,2);

%% study weights 
w = DB.studyweight;
w = w ./ mean(w); 

%% OLD - REMOVE? 
% load canlab core brain mask
% UPDATE TO VARARGIN SO FLEXIBLE
% mask_path = which('brainmask.nii');
% 
% mask = fmri_data(mask_path);
% 
% % display # voxels
% nvox = mask.dat; nvox = sum(nvox>0);
% fprintf(1,'\nVoxels in mask: %3.2f\n',nvox);

%% OLD - REMOVE?

% output images -- initialize
% --------------------------------------------
% betas = NaN * zeros([dims(1:2) cols]);
% t = betas;
% p = ones([dims(1:2) cols]);
% 
% Fmap = NaN * zeros([dims(1:2)]);
% omnp = ones([dims(1:2)]);
% 
% omnchi2 = NaN * zeros([dims(1:2)]);
% chi2pmap = omnp;
% chi2warn = Fmap;
% 
% if ~isempty(Xi), avgs = NaN * zeros([dims(1:2) size(Xi,1)]);, end

%% output images -- initialize
betas = NaN * repmat(zeros(size(Y.dat(:, 1))), 1, cols);
t = betas;
p = betas;

Fmap = NaN * zeros(size(Y.dat(:, 1)));
omnp = ones([size(Y.dat)]);

omnchi2 = NaN * zeros([size(Y.dat(:, 1))]);
chi2pmap = omnp;
chi2warn = Fmap;

%% voxel-wise logistic regression

% loop through voxels, run & save stats %
for k = 1:length(y)

    if any(y(:) == 0)
        %  We can't run Logistic for this voxel; it won't be meaningful.
        
        % Logistic regression does not return accurate results if the
        % proportions are 100% (i.e., if some cells in tab table are empty)
        % If so, shrink values a bit so that we can estimate regression
        
        y(y==0) = 0+.01;
        y(y==1) = 1-.01;
    end

    % logistic regression at a voxel %
    [b,dev,stats]=glmfit(X,[y(k, :)' ones(size(y(k, :)'))],'binomial','logit','off',[],w); % pvals are more liberal than Fisher's Exact!

    % omnibus test - R^2 change test
        % --------------------------------------------------------
        sstot = y(k, :)'*y(k, :);
        r2full = (sstot - (stats.resid' * stats.resid)) ./ sstot;
        dffull = stats.dfe;

        [br,devr,statsr]=glmfit(ones(size(y(k, :)')),[y(k, :)' ones(size(y(k, :)'))],'binomial','logit','off',[],w,'off');
        r2red = (sstot - (statsr.resid' * statsr.resid)) ./ sstot;
        dfred = statsr.dfe;

        if r2full < r2red, fprintf(1,'Warning!'); r2red = r2full;,drawnow; fprintf(1,'\b\b\b\b\b\b\b\b'); end
        [F,op,df1,df2] = compare_rsquare_noprint(r2full,r2red,dffull,dfred);
        % --------------------------------------------------------
        
        % save output from voxel
        % --------------------------------------------
        betas(k,:) = b(2:end);
        t(k,:) = stats.t(2:end);
        p(k,:) = stats.p(2:end);

%         Fmap(k) = F;
%         omnp(k) = op;
    %end
        
    
    if mod(k,10)==0, fprintf(1,'\b\b\b\b%04d',k);,end
    %if k == 1000, fprintf(1,'%3.0f s per 1000 vox.',etime(clock,et)), end


end

% save('FirstTryLog.mat');

% write to statistic image %
t_result = statistic_image('dat', t, 'type', 'T', 'dfe', df2);
t_result.volInfo = Y.volInfo;

% b_result = statistic_image('dat', betas, 'type', 'b', 'dfe', df2);
% b_result.volInfo = Y.volInfo;

return



