function wjz_script_faster_rcnn_ucf_11()
close all;
clc;
clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
opts.caffe_version          = 'caffe_faster_rcnn';
opts.gpu_id                 = auto_select_gpu;
active_caffe_mex(opts.gpu_id, opts.caffe_version);

opts.per_nms_topN           = 6000;
opts.nms_overlap_thres      = 0.7;
opts.after_nms_topN         = 300;
opts.use_gpu                = true;

opts.test_scales            = 600;

%% -------------------- INIT_MODEL --------------------
% model_dir                   = fullfile(pwd, '../output', 'faster_rcnn_final', 'faster_rcnn_VOC0712_vgg_16layers'); %% VGG-16
% model_dir                   = fullfile(pwd, '../output', 'faster_rcnn_final', 'faster_rcnn_VOC0712_ZF'); %% ZF
model_dir                   = fullfile(pwd, 'output', 'faster_rcnn_final', 'faster_rcnn_VOC0712plus_vgg_16layers'); %% VGG-16-augmented
proposal_detection_model    = load_proposal_detection_model(model_dir);

proposal_detection_model.conf_proposal.test_scales = opts.test_scales;
proposal_detection_model.conf_detection.test_scales = opts.test_scales;
if opts.use_gpu
    proposal_detection_model.conf_proposal.image_means = gpuArray(proposal_detection_model.conf_proposal.image_means);
    proposal_detection_model.conf_detection.image_means = gpuArray(proposal_detection_model.conf_detection.image_means);
end

% caffe.init_log(fullfile(pwd, 'caffe_log'));
% proposal net
rpn_net = caffe.Net(proposal_detection_model.proposal_net_def, 'test');
rpn_net.copy_from(proposal_detection_model.proposal_net);
% fast rcnn net
fast_rcnn_net = caffe.Net(proposal_detection_model.detection_net_def, 'test');
fast_rcnn_net.copy_from(proposal_detection_model.detection_net);

% set gpu/cpu
if opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end       

%% -------------------- WARM UP --------------------
% the first run will be slower; use an empty image to warm up
for j = 1:2 % we warm up 2 times
    im = uint8(ones(375, 500, 3)*128);
    if opts.use_gpu
        im = gpuArray(im);
    end
    [boxes, scores]             = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im);
    aboxes                      = boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);
    if proposal_detection_model.is_share_feature
        [boxes, scores]             = fast_rcnn_conv_feat_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
            rpn_net.blobs(proposal_detection_model.last_shared_output_blob_name), ...
            aboxes(:, 1:4), opts.after_nms_topN);
    else
        [boxes, scores]             = fast_rcnn_im_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
            aboxes(:, 1:4), opts.after_nms_topN);
    end
end
%% -------------------- TESTING --------------------
disp('test up');
wjz_root='~/opticalFlow_sports';
wjz_save_path = '~/wjz_boxes_ucf_sports_vgg_plus';
wjz_test_file = '~/caffe-sports-spatial/examples/ucf_sports/split_test.txt';
f_test = fopen(wjz_test_file);

while ~feof(f_test),
    data = fgetl(f_test);
    idx_slash = strfind(data, '/');
    idx_blank = strfind(data, ' ');
    class = data(idx_slash(4)+1:idx_slash(5)-1);
    No = data(idx_slash(5)+1:idx_slash(6)-1);
    frame = data(idx_blank(1)+1:idx_blank(2)-1);
    
    path = [wjz_save_path '/' class '/' No];
    mkdir(path);
    
    im_path = [wjz_root '/' class '/' No '/im'];
    for i = 1 : str2double(frame),
        tmp2 = num2str(i,'%04d');
        im = imread([im_path '/image_' tmp2 '.jpg']);
        if opts.use_gpu
            im = gpuArray(im);
        end
         % test proposal
        [boxes, scores] = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im);
        aboxes = boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);  
        % test detection
        if proposal_detection_model.is_share_feature
            [boxes, scores] = fast_rcnn_conv_feat_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
                rpn_net.blobs(proposal_detection_model.last_shared_output_blob_name), ...
                aboxes(:, 1:4), opts.after_nms_topN);
        else
            [boxes, scores]  = fast_rcnn_im_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
                aboxes(:, 1:4), opts.after_nms_topN);
        end
        classes = proposal_detection_model.classes;
        boxes_cell = cell(length(classes), 1);
        thres = 0.6;
        for idx = 1:length(boxes_cell)
            boxes_cell{idx} = [boxes(:, (1+(idx-1)*4):(idx*4)), scores(:, idx)];
            boxes_cell{idx} = boxes_cell{idx}(nms(boxes_cell{idx}, 0.3), :);

            I = boxes_cell{idx}(:, 5) >= thres;
            boxes_cell{idx} = boxes_cell{idx}(I, :);
        end
%         figure(j);
%         showboxes(im, boxes_cell, classes, 'voc');
%         pause(0.1);
        save([path '/' num2str(i) '.mat'],'boxes_cell');
    end
end    
fclose(f_test);

caffe.reset_all(); 
clear mex;
disp('test done');
end

function proposal_detection_model = load_proposal_detection_model(model_dir)
    ld                          = load(fullfile(model_dir, 'model'));
    proposal_detection_model    = ld.proposal_detection_model;
    clear ld;
    
    proposal_detection_model.proposal_net_def ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net_def);
    proposal_detection_model.proposal_net ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net);
    proposal_detection_model.detection_net_def ...
                                = fullfile(model_dir, proposal_detection_model.detection_net_def);
    proposal_detection_model.detection_net ...
                                = fullfile(model_dir, proposal_detection_model.detection_net);
    
end

function aboxes = boxes_filter(aboxes, per_nms_topN, nms_overlap_thres, after_nms_topN, use_gpu)
    % to speed up nms
    if per_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), per_nms_topN), :);
    end
    % do nms
    if nms_overlap_thres > 0 && nms_overlap_thres < 1
        aboxes = aboxes(nms(aboxes, nms_overlap_thres, use_gpu), :);       
    end
    if after_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), after_nms_topN), :);
    end
end
