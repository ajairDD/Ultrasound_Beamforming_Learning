function out = beamform_fi_mvdr_prepared(prep,opts)
%BEAMFORM_FI_MVDR_PREPARED Apply receive-domain MVDR to prepared FI data.
%
% For one already focused pixel, active receive data are
%
%   s = [s1 ... sM].
%
% MVDR solves
%
%   minimize  w^H R w
%   subject to w^H a = 1
%
% Because Tx/Rx delays already aligned the desired pixel,
%
%   a = ones(L,1).
%
% Covariance is estimated with spatial smoothing over all contiguous
% subarrays of length L.
%
% Diagonal loading:
%
%   R_loaded = R + delta * trace(R)/L * I.
%
% By default, averaged MVDR output is multiplied by M so a perfectly
% coherent signal has approximately the same amplitude scale as DAS.
%
% opts:
%   subarray_fraction   default 0.5
%   diagonal_loading   default 1e-2
%   forward_backward   default false
%   scale_to_das       default true
%   dynamic_range_db   default 60
%   verbose            default false

    if nargin < 2 || isempty(opts)
        opts = struct();
    end

    opts = apply_defaults(opts);

    assert(opts.subarray_fraction > 0 && ...
           opts.subarray_fraction <= 1, ...
        'subarray_fraction must be in (0,1].');

    assert(opts.diagonal_loading >= 0 && ...
           isfinite(opts.diagonal_loading), ...
        'diagonal_loading must be finite and non-negative.');

    [Nz,N_channels,N_waves] = size(prep.aligned_samples);

    assert(size(prep.active_mask,1) == Nz && ...
           size(prep.active_mask,2) == N_channels && ...
           size(prep.active_mask,3) == N_waves, ...
        'active_mask shape mismatch.');

    mvdr_analytic = complex(zeros(Nz,N_waves));
    subarray_length_map = zeros(Nz,N_waves);

    n_fallback_small = 0;
    n_fallback_noncontiguous = 0;
    n_fallback_numerical = 0;

    for iw = 1:N_waves

        if opts.verbose && mod(iw-1,max(1,floor(N_waves/10))) == 0
            fprintf('MVDR wave %d / %d ...\n',iw,N_waves);
        end

        for iz = 1:Nz

            active_idx = find(prep.active_mask(iz,:,iw));
            M = numel(active_idx);

            das_pixel = prep.das_analytic(iz,iw);

            if M < 2
                mvdr_analytic(iz,iw) = das_pixel;
                n_fallback_small = n_fallback_small + 1;
                continue;
            end

            % Spatial smoothing assumes physically adjacent elements.
            if any(diff(active_idx) ~= 1)
                mvdr_analytic(iz,iw) = das_pixel;
                n_fallback_noncontiguous = ...
                    n_fallback_noncontiguous + 1;
                continue;
            end

            s = prep.aligned_samples(iz,active_idx,iw);
            s = reshape(s,1,[]);

            L = floor(opts.subarray_fraction*M);
            L = max(2,min(M,L));

            N_sub = M-L+1;
            subarray_length_map(iz,iw) = L;

            X = complex(zeros(L,N_sub));

            for j = 1:N_sub
                X(:,j) = s(j:j+L-1).';
            end

            % Spatially smoothed covariance [L x L].
            R = (X*X')/N_sub;

            if opts.forward_backward
                J = flipud(eye(L));
                R = 0.5*(R + J*conj(R)*J);
            end

            trace_per_element = real(trace(R))/L;

            if ~(isfinite(trace_per_element) && trace_per_element > 0)
                mvdr_analytic(iz,iw) = das_pixel;
                n_fallback_numerical = n_fallback_numerical + 1;
                continue;
            end

            R_loaded = ...
                R + ...
                opts.diagonal_loading*trace_per_element*eye(L);

            a = ones(L,1);

            u = R_loaded\a;
            denom = a'*u;

            if ~(isfinite(real(denom)) && ...
                 isfinite(imag(denom)) && ...
                 abs(denom) > eps)
                mvdr_analytic(iz,iw) = das_pixel;
                n_fallback_numerical = n_fallback_numerical + 1;
                continue;
            end

            w = u/denom;

            constraint_error = abs(w'*a-1);

            if constraint_error > 1e-6
                mvdr_analytic(iz,iw) = das_pixel;
                n_fallback_numerical = n_fallback_numerical + 1;
                continue;
            end

            y_sub = w'*X;
            y = mean(y_sub);

            if opts.scale_to_das
                y = M*y;
            end

            mvdr_analytic(iz,iw) = y;
        end
    end

    das_env = abs(prep.das_analytic);
    mvdr_env = abs(mvdr_analytic);

    das_peak = max(das_env(:));
    mvdr_peak = max(mvdr_env(:));

    assert(das_peak > 0 && mvdr_peak > 0, ...
        'DAS or MVDR image is all zero.');

    out = struct();

    out.mvdr_analytic = mvdr_analytic;
    out.mvdr_envelope = mvdr_env;

    out.mvdr_db_common = ...
        to_db(mvdr_env,das_peak,opts.dynamic_range_db);

    out.mvdr_db_self = ...
        to_db(mvdr_env,mvdr_peak,opts.dynamic_range_db);

    out.das_analytic = prep.das_analytic;
    out.das_envelope = das_env;
    out.das_db = ...
        to_db(das_env,das_peak,opts.dynamic_range_db);

    out.x_axis = prep.x_axis;
    out.z_axis = prep.z_axis;

    out.subarray_length_map = subarray_length_map;

    out.n_fallback_small = n_fallback_small;
    out.n_fallback_noncontiguous = n_fallback_noncontiguous;
    out.n_fallback_numerical = n_fallback_numerical;

    out.options = opts;
end

function opts = apply_defaults(opts)

    defaults = struct( ...
        'subarray_fraction',0.5, ...
        'diagonal_loading',1e-2, ...
        'forward_backward',false, ...
        'scale_to_das',true, ...
        'dynamic_range_db',60, ...
        'verbose',false);

    names = fieldnames(defaults);

    for k = 1:numel(names)
        name = names{k};

        if ~isfield(opts,name) || isempty(opts.(name))
            opts.(name) = defaults.(name);
        end
    end
end

function db = to_db(env,reference_peak,dynamic_range)

    db = 20*log10(env/(reference_peak+eps)+eps);

    db(db < -dynamic_range) = -dynamic_range;
    db(db > 0) = 0;
end
