function [subjVar, subjVar_created]  = CreateSubjVar(sbj_name, dirs, data_format, fsDir_local)

if strcmp(data_format, 'edf')
    % Load a given globalVar
    gv_dir = dir(fullfile([dirs.data_root filesep 'originalData/' sbj_name]));
    gv_inds = arrayfun(@(x) contains(x.name, 'global'), gv_dir);
    fn_tmp = gv_dir(gv_inds);
    load([fn_tmp(1).folder filesep fn_tmp(1).name])
else
end


%% Cortex and channel label correction
subjVar = [];
cortex = getcort(dirs);
% native_coord = importCoordsFreesurfer(dirs);
% fs_chan_names = importElectNames(dirs);
[MNI_coord, chanInfo, native_coord, avgVids, subVids] = sub2AvgBrainCustom([],dirs, fsDir_local);
fs_chan_names = chanInfo.Name;
close all
V = importVolumes(dirs);

subjVar.sbj_name = sbj_name;
subjVar.cortex = cortex;
subjVar.V = V;

%% Correct channel name
% Load naming from google sheet
if strcmp(data_format, 'edf')
    [DOCID,GID] = getGoogleSheetInfo('chan_names_ppt', 'chan_names_fs_figures');
else
    [DOCID,GID] = getGoogleSheetInfo('chan_names_ppt', 'chan_names_ppt_log');
end


googleSheet = GetGoogleSpreadsheet(DOCID, GID);
ppt_chan_names = googleSheet.(sbj_name);
ppt_chan_names = ppt_chan_names(~cellfun(@isempty, ppt_chan_names)); % remove empty cells 
ppt_chan_names = cellfun(@(x) strrep(x, ' ', ''), ppt_chan_names, 'UniformOutput', false); % Remove eventual spaces

nchan_fs = length(fs_chan_names);
if strcmp(sbj_name, 'S17_117_MC')
    chan_comp = globalVar.channame;
    nchan_cmp = length(globalVar.channame);
else
    chan_comp = ppt_chan_names;
    nchan_cmp = length(ppt_chan_names); 
end

in_chan_cmp = false(1,nchan_fs);
for i = 1:nchan_fs
    in_chan_cmp(i) = ismember(fs_chan_names(i),chan_comp);
end

in_fs = false(1,nchan_cmp);
for i = 1:nchan_cmp
    in_fs(i) = ismember(chan_comp(i),fs_chan_names);
end

    % do nothing

if sum(in_chan_cmp) == length(in_chan_cmp) && sum(in_fs) == length(in_fs)
% 1: More channels in freesurfer
elseif sum(in_chan_cmp) < length(in_chan_cmp) && sum(in_fs) == length(in_fs)
    fs_chan_names = fs_chan_names(in_chan_cmp);
    native_coord = native_coord(in_chan_cmp,:);
    MNI_coord = MNI_coord(in_chan_cmp,:);
    
    % 2: More channels in EDF/TDT
elseif sum(in_chan_cmp) == length(in_chan_cmp) && sum(in_fs) < length(in_fs)
    fs_chan_names_tmp = cell(nchan_cmp,1);
    fs_chan_names_tmp(in_fs) = fs_chan_names;
    fs_chan_names_tmp(in_fs==0) = chan_comp(in_fs==0);
    fs_chan_names = fs_chan_names_tmp;
    
    native_coord_tmp = nan(nchan_cmp,3,1);
%     native_coord_tmp = nan(size(native_coord,1),size(native_coord,2),1);
    native_coord_tmp(in_fs,:) = native_coord;
    native_coord = native_coord_tmp;
    
    MNI_coord_tmp = nan(nchan_cmp,3,1);
%     MNI_coord_tmp = nan(size(MNI_coord,1),size(MNI_coord,2),1);
    MNI_coord_tmp(in_fs,:) = MNI_coord;
    MNI_coord = MNI_coord_tmp;
    % More in 
elseif sum(in_chan_cmp) < length(in_chan_cmp) && sum(in_fs) < length(in_fs)

    disp(sbj_name)
    disp('channels in EDF/TDT which are not in FS')
    chan_comp(in_fs == 0)
    disp('channels in FS which are not in EDF/TDT')
    fs_chan_names(in_chan_cmp == 0)
    warning('this exception is not automatically fixable, please decide:')

    prompt = 'Do you want to remove the FS-only and add the EDF/TDT-only?';
    ID = input(prompt,'s');
    if strcmp(ID, 'y')
        % First remove the FS which are not in EDF/TDT
        fs_chan_names = fs_chan_names(in_chan_cmp);
        native_coord = native_coord(in_chan_cmp,:);
        MNI_coord = MNI_coord(in_chan_cmp,:);
        
        % Second add the EDF/TDT which are not in FS
        fs_chan_names_tmp = cell(nchan_cmp,1);
        fs_chan_names_tmp(in_fs) = fs_chan_names;
        fs_chan_names_tmp(in_fs==0) = chan_comp(in_fs==0);
        fs_chan_names = fs_chan_names_tmp;
        
        native_coord_tmp = nan(size(native_coord,1),size(native_coord,2),1);
        MNI_coord_tmp = nan(size(MNI_coord,1),size(MNI_coord,2),1);

        if in_fs(end) == 0
           native_coord_tmp(end+1,:) = nan; 
           MNI_coord_tmp(end+1,:) = nan; 
        else
        end
        
        native_coord_tmp(in_fs,:) = native_coord;
        native_coord = native_coord_tmp;
        
        MNI_coord_tmp(in_fs,:) = MNI_coord;
        MNI_coord = MNI_coord_tmp;
    else
        warning('channel labels not fixed, please double check PPT/FS')
        mismatch_labels = 1;
    end
end

if ~exist('mismatch_labels')
    %% Reorder and save in subjVar
    new_order = nan(1,nchan_cmp);
    for i = 1:nchan_cmp
        tmp = find(ismember(fs_chan_names, chan_comp(i)));
        if ~isempty(tmp)
            new_order(i) = tmp(1);
        end
    end
    
    subjVar.native_coord = native_coord(new_order,:);
    subjVar.MNI_coord = MNI_coord(new_order,:);
    if strcmp(data_format, 'TDT')
        subjVar.elect_names = chan_comp;
    else
        %     subjVar.elect_names = chan_comp;
        if isfield(globalVar, 'channame')
            subjVar.elect_names = globalVar.channame;
        else
            subjVar.elect_names = chan_comp;
        end
    end
    
    
    %% Demographics
    subjVar.demographics = GetDemographics(sbj_name);
    if isempty(subjVar.demographics)
        warning(['There is no demographic info for ' sbj_name '. Please add it to the google sheet.'])
    else
    end
    
    if ~exist([dirs.original_data filesep sbj_name], 'dir')
        mkdir([dirs.original_data filesep sbj_name])
    else
    end
    
    %% Save subjVar
    if exist([dirs.original_data filesep sbj_name filesep 'subjVar_' sbj_name '.mat'], 'file')
        prompt = ['subjVar already exist for ' sbj_name ' . Replace it? (y or n):'] ;
        ID = input(prompt,'s');
        if strcmp(ID, 'y')
            save([dirs.original_data filesep sbj_name filesep 'subjVar_' sbj_name '.mat'], 'subjVar')
            disp(['subjVar saved for ' sbj_name])
            subjVar_created = 1;
        else
            warning(['subjVar NOT saved for ' sbj_name])
        end
    else
        save([dirs.original_data filesep sbj_name filesep 'subjVar_' sbj_name '.mat'], 'subjVar')
        disp(['subjVar saved for ' sbj_name])
        subjVar_created = 1;
    end
    
else
    subjVar_created = 0;
end

end
