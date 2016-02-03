%% ��ɫRGB

function res = CalcuHoRGB(patch) 
    space = 16;
    [ht, wd, dim] = size(patch);
    if dim == 1
        res = 0;
        disp('input is gray image, reported from Func CalcuColorHist');
        return;
    end
    rgb = reshape(patch, ht*wd,dim);  % ÿ����ɫͨ����Ϊһ��
    [hist_rgb, ~] = hist(rgb, [0:space:255]);
    for i = 1 : dim % rgb��ͨ��
        hist_rgb(:, i) = hist_rgb(:, i) / sum(hist_rgb(:, i));
    end
    [n_bin, dim] = size(hist_rgb);
    res = reshape(hist_rgb, 1, dim * n_bin);
end