function WaveletFilterAll(sbj_name, project_name, bn, dirs,el,freq_band,span,fs_targ, norm, datatype)

%% INPUTS
%   sbj_name:               subject name
%   project_name:           name of task
%   bn:                     names of blocks to be analyed (cell of strings)
%   dirs:                   directories pointing to files of interest (generated by InitializeDirs)
%   el (optional):          can select subset of electrodes to epoch (default: all)
%   freq_band:              vector containing frequencies at which wavelet is computed (in Hz),
%                           or string (e.g. 'HFB') corresponding to
%                           particular set of freqs (returned by genFreqs.m)
%   span (optional):        span of wavelet (i.e. width of gaussian that forms
%                           wavelet, in units of cycles- specific to each
%                           frequency)
%   fs_targ (optional):     target sampling rate of wavelet output
%   norm (optional):        normalize amplitude of timecourse within each frequency
%                           band (to eliminate 1/f power drop with frequency)
%   datatype :              'Band' or 'Spec'
%
%
if strcmp(datatype,'Band')
    avgfreq = true;
else
    avgfreq = false;
end


if ~ischar(freq_band)
    freqs = freq_band;
    % if freq_band input contains numbers, create label for band
    freq_band = [num2str(freqs(1)),'_to_',num2str(freqs(end))];
    freq_band = strrep(freq_band,'.','_');
else
    freqs = genFreqs(freq_band);
end

if isempty(span)
    span = 1;
end
if isempty(norm)
    norm = true;
end
%%
% Load globalVar
fn = sprintf('%s/originalData/%s/global_%s_%s_%s.mat',dirs.data_root,sbj_name,project_name,sbj_name,bn);
load(fn,'globalVar');

if strcmp(datatype,'Band')
    data_root=fullfile(dirs.data_root,'BandData');%globalVar.BandData;  
else
    data_root=fullfile(dirs.data_root,'SpecData');%globalVar.SpecData; 
end
% dir_out = [data_root,freq_band,'Data',filesep,sbj_name,filesep,bn];c
dir_out = [data_root,freq_band,filesep,sbj_name,filesep,bn];
if ~exist(dir_out, 'dir')
    mkdir(dir_out)
end

% eval(['globalVar.',freq_band,'Data = dir_out;']);
% save (fn,'globalVar')

if isempty(fs_targ)
    if avgfreq
        fs_targ = 500;
    else
        fs_targ = 200;
    end
end

%% Per electrode
load(sprintf('%s/%s/%s/%s/CARiEEG%s_%.2d.mat',dirs.data_root,'/CARData/CAR',sbj_name,bn,bn,el));

%load(sprintf('%s/CARiEEG%s_%.2d.mat',globalVar.CARData,bn,el));

data = WaveletFilter(data.wave,data.fsample,fs_targ,freqs,span,norm,avgfreq);
data.label = globalVar.channame{el};
data_root= sprintf('%s/%s/%s/%s/%s/',dirs.data_root,([datatype,'Data']),freq_band,sbj_name,bn);
fn_out = sprintf('%s/%s/%s/%s/%s/%siEEG%s_%.2d.mat',dirs.data_root,([datatype,'Data']),freq_band,sbj_name,bn,freq_band,bn,el);

if ~exist(data_root)
   mkdir(data_root) 
end

save(fn_out,'data')
disp(['Wavelet filtering: Block ', bn,', Elec ',num2str(el)])


end