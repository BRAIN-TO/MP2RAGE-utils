function [MP2RAGEimgRobustPhaseSensitive, multiplyingFactor] = RobustCombination(NoisyImage,MP2RAGE,regularisation,visualise)

% This script allows the creation of MP2RAGE T1w images without the strong
% background noise in air regions.
%
% MP2RAGE is a structure that should have the following fields:
% MP2RAGE.filenameUNI
% MP2RAGE.filenameINV1
% MP2RAGE.filenameINV2
% MP2RAGE.filenameOUT - it does not have to exist, only if you want to save the output file.
% If you have already done your 'homework' with your datasets using the same protocol
% you can then just use this function shows one possible implementation of the methods suggested
% in:
%
% O'Brien, et al, 2014.
% Robust T1-Weighted Structural Brain Imaging and Morphometry at 7T Using MP2RAGE
% PLOS ONE 9, e99676. doi:10.1371/journal.pone.0099676
% http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0099676
%
% Although in the original paper the method only worked on raw multichannel
% data, here that constraint has been overcome and the correction can be
% implemented if both SOS images of the two inversion times exist and a
% MP2RAGE T1w image that has been calculated directly from the multichannel
% data as initially proposed in Marques et al, Neuroimage, 2009

if nargin<2 || isempty(regularisation)
    multiplyingFactor = 1;
else
    multiplyingFactor = regularisation;
end
if nargin<3
    visualise = true;
end
FinalChoice = 'n';


%% defines relevant functions

MP2RAGErobustfunc = @(INV1, INV2, beta)(conj(INV1).*INV2-beta) ./ (INV1.^2 + INV2.^2 + 2*beta);
rootsquares_pos   = @(a, b, c)(-b + sqrt(b.^2 - 4*a.*c)) ./ (2*a);
rootsquares_neg   = @(a, b, c)(-b - sqrt(b.^2 - 4*a.*c)) ./ (2*a);


%% load Data
MP2RAGEimg     = load_untouch_nii(NoisyImage);
INV1img        = load_untouch_nii(MP2RAGE.filenameINV1);
INV2img        = load_untouch_nii(MP2RAGE.filenameINV2);
MP2RAGEimg.img = double(MP2RAGEimg.img);
INV1img.img    = double(INV1img.img);
INV2img.img    = double(INV2img.img);

if min(MP2RAGEimg.img(:))>=0 && max(MP2RAGEimg.img(:))>=0.51
    % converts MP2RAGE to -0.5 to 0.5 scale - assumes that it is getting only positive values
    MP2RAGEimg.img = (MP2RAGEimg.img - max(MP2RAGEimg.img(:))/2) ./ max(MP2RAGEimg.img(:));
    integerformat = 1;
else
    integerformat = 0;
end


%% computes correct INV1 dataset

% Gives the correct polarity to INV1
INV1img.img = sign(MP2RAGEimg.img) .* INV1img.img;

% Because the MP2RAGE INV1 and INV2 is a summ of squares data, while the
% MP2RAGEimg is a phase sensitive coil combination.. some more maths has to
% be performed to get a better INV1 estimate which here is done by assuming
% both INV2 is closer to a real phase sensitive combination

INV1pos = rootsquares_pos(-MP2RAGEimg.img, INV2img.img, -INV2img.img.^2 .* MP2RAGEimg.img);
INV1neg = rootsquares_neg(-MP2RAGEimg.img, INV2img.img, -INV2img.img.^2 .* MP2RAGEimg.img);

INV1final = INV1img.img;
INV1final(abs(INV1img.img-INV1pos) >  abs(INV1img.img-INV1neg)) = INV1neg(abs(INV1img.img-INV1pos) >  abs(INV1img.img-INV1neg));
INV1final(abs(INV1img.img-INV1pos) <= abs(INV1img.img-INV1neg)) = INV1pos(abs(INV1img.img-INV1pos) <= abs(INV1img.img-INV1neg));


%% visualizing the data
pos = round(3/5*size(INV1final));
% if visualise
%     figureJ(200)
%     subplot(411)
%     Orthoview(INV1pos, pos, [-200 200])
%     title('positive root')
%
%     subplot(412)
%     Orthoview(INV1neg, pos, [-200 200])
%     title('negative root')
%
%     subplot(413)
%     Orthoview(INV1img.img, pos, [-200 200])
%     title('Phase Corrected Sum of Squares  root')
%
%     subplot(414)
%     Orthoview(INV1final, pos, [-200 200])
%     title('INV1 final')
% end


%% lambda calculation

% Usually the multiplicative factor shouldn't be greater then 10, but that
% is not the ase when the image is bias field corrected, in which case the
% noise estimated at the edge of the image might not be such a good measure

while ~strcmpi(FinalChoice, 'y')
    
    noiselevel = multiplyingFactor*mean(mean(mean(INV2img.img(1:end, end-10:end, end-10:end))));
    
    % MP2RAGEimgRobustScanner = MP2RAGErobustfunc(INV1img.img, INV2img.img, noiselevel.^2);
    MP2RAGEimgRobustPhaseSensitive = MP2RAGErobustfunc(INV1final, INV2img.img, noiselevel.^2);
    
    if visualise
        
        % Robust Image view
        range = [-0.5 0.40];
        f1=figure(1);
        f1.Visible = 'off';
        subplot(211)
        Orthoview(MP2RAGEimg.img, pos, range);
        title('Input Image');
        
        % subplot(312)
        % Orthoview(MP2RAGEimgRobustScanner, pos, range)
        % title('MP2RAGE Robust Scanner')
        
        subplot(212)
        Orthoview(MP2RAGEimgRobustPhaseSensitive, pos, range);
        title('Robust Image');
        ylabel(['Noise level = ' num2str(multiplyingFactor)])
        
        saveas(f1,MP2RAGE.filenameIMGOUT); close all;
        
        if isempty(regularisation)
            FinalChoice = input('Is it a satisfactory noise level?? (y/n) [n]: ', 's');
            if strcmpi(FinalChoice,'y')
                fprintf('Final regularisation noise level = %g\n\n', multiplyingFactor)
            else
                multiplyingFactor = input(['New regularisation noise level (current = ' num2str(multiplyingFactor) '): ']);
            end
        else
            FinalChoice = 'y';
        end
        
    else
        
        FinalChoice = 'y';
        
    end
    
end


%% Saving data if that is the case
% if isfield(MP2RAGE, 'filenameOUT')
%     if ~isempty(MP2RAGE.filenameOUT)
% %         disp(['Saving: ' MP2RAGE.filenameOUT])
%         if integerformat==0
MP2RAGEimg.hdr.dime.datatype=16;
MP2RAGEimg.hdr.dime.bitpix=32;
MP2RAGEimg.img = round(4095*(MP2RAGEimgRobustPhaseSensitive + 0.5));
save_untouch_nii(MP2RAGEimg, MP2RAGE.filenameOUT);
%         else
%             MP2RAGEimg.img = round(4095*(MP2RAGEimgRobustPhaseSensitive + 0.5));
%             save_untouch_nii(MP2RAGEimg, MP2RAGE.filenameOUT);
%         end
%     end
% end
