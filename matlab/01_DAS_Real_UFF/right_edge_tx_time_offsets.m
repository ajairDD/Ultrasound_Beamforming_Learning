function offsets = right_edge_tx_time_offsets(channel_data, half_aperture_elements)
%RIGHT_EDGE_TX_TIME_OFFSETS Candidate RF timing correction for clipped FI Tx.
% This explicitly tests a last-active-element timing-reference hypothesis.
% It is NOT a general UFF correction and must not be enabled by filename.
%
% For the local CIRS points acquisition, half_aperture_elements=16 predicts
% the observed onset at Tx 113 and the subsequent inter-Tx phase drift.
% UFF stores no usable actual Tx apodization for this file (NaNs); therefore
% the acquisition mechanism remains an inference, not verified metadata.
%
% The nominal reference is at x_source + half_aperture_elements*pitch.
% When clipped at the last element, the reference path becomes shorter:
%   dt = (hypot(z_focus, nominal_half_width)
%         - hypot(z_focus, clipped_right_distance)) / c.
% Positive offsets are ADDED to query time in both RTB and conventional DAS.
% Units: seconds. Output order: original sequence order, [N_waves,1].

    assert(isscalar(half_aperture_elements) && ...
        isfinite(half_aperture_elements) && half_aperture_elements > 0 && ...
        half_aperture_elements == round(half_aperture_elements), ...
        'half_aperture_elements must be a positive integer.');
    px = double(channel_data.probe.x(:));
    assert(all(diff(px) > 0) && max(abs(diff(px)-median(diff(px)))) < 1e-8, ...
        'This hypothesis requires an ordered, uniform linear array.');
    assert(max(abs(double(channel_data.probe.y(:)))) < 1e-9 && ...
        max(abs(double(channel_data.probe.z(:)))) < 1e-9, ...
        'This hypothesis requires a linear array in the z=0 plane.');
    half_width = half_aperture_elements * median(diff(px));
    offsets = zeros(channel_data.N_waves,1);
    for iw = 1:channel_data.N_waves
        wave = channel_data.sequence(iw);
        sx = double(wave.source.x);
        sz = double(wave.source.z);
        assert(wave.wavefront == uff.wavefront.spherical && sz > 0 && ...
            abs(double(wave.source.y)) < 1e-9 && ...
            abs(double(wave.origin.x)-sx) < 1e-7 && ...
            abs(double(wave.origin.z)) < 1e-9, ...
            'This hypothesis requires unsteered focused linear FI.');
        % UFF geometry is stored as single; spherical-coordinate conversion
        % can move source.x a few nanometers beyond the last element.
        assert(sx >= px(1)-1e-7 && sx <= px(end)+1e-7, ...
            'Focus x must be within the probe footprint.');
        right_distance = min(half_width,max(0,px(end)-sx));
        offsets(iw) = (hypot(sz,half_width)-hypot(sz,right_distance)) ...
            / double(wave.sound_speed);
    end
end
