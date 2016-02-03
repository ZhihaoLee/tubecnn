function res = TubeChoose(cts, f_cell, cnn_cell,loc_cell, img_cell) 

    tube_res = [];
    for idx = 1:size(cts,1)        
        tube_tmp = [];
        for f_idx = 1:max(size(f_cell))
            ct_tmp = cts(idx,:);
            feat = f_cell{f_idx};
            pos_cnn = cnn_cell{f_idx};   
            loc_rec = loc_cell{f_idx};
            img = img_cell{f_idx};
            if isempty(feat)
                tube_p = [];
            else
                num = size(feat,1);
                ct_tmp = repmat(ct_tmp, num, 1);
                dis = sqrt(sum((ct_tmp-feat).^2, 2));
                loc = find(dis==min(dis));
                loc = loc_rec(loc(1));
                tube_p = pos_cnn(loc,:); % ����λ��  % ��¼��Чλ��               
                % tube_f = feat(loc(1),:); % �����ڵ�����
                % res = NegSampleGenerate(tube_p, img); % ����������                
            end
            tube_tmp{1,f_idx} = tube_p;
        end     
        tube_res{1,idx} = tube_tmp;      
    end
     
    res = tube_res;
end