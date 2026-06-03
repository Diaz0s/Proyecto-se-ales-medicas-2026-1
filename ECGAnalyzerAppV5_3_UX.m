classdef ECGAnalyzerAppV5_3_UX< matlab.apps.AppBase
% =========================================================================
%  ECG ANALYZER — Laboratorio Virtual de Señales Biomédicas
%  Compatible con archivos WFDB/MIT-BIH (.dat + .hea)
%  Formatos: 212 (12-bit) y 16 (int16)
%
%  USO:  app = ECGAnalyzerApp;
% =========================================================================

    % ------------------------------------------------------------------ %
    %  PROPIEDADES UI                                                      %
    % ------------------------------------------------------------------ %
    properties (Access = public)
        UIFigure        matlab.ui.Figure
        GridMain        matlab.ui.container.GridLayout

        % Panel izquierdo
        PanelLeft       matlab.ui.container.Panel
        GridLeft        matlab.ui.container.GridLayout

        % Carga de archivo
        PanelFile       matlab.ui.container.Panel
        BtnLoad         matlab.ui.control.Button
        LblFile         matlab.ui.control.Label
        LblFs           matlab.ui.control.Label
        LblDur          matlab.ui.control.Label
        LblFormat       matlab.ui.control.Label

        % Configuración de señal
        PanelConfig     matlab.ui.container.Panel
        DdLead          matlab.ui.control.DropDown
        BtnQuickFilt    matlab.ui.control.Button
        BtnResetSig     matlab.ui.control.Button

        % Selección de ventana
        PanelWindow     matlab.ui.container.Panel
        EfWinStart      matlab.ui.control.NumericEditField
        EfWinEnd        matlab.ui.control.NumericEditField
        BtnApplyWin     matlab.ui.control.Button
        BtnResetWin     matlab.ui.control.Button

        % Estado global
        PanelStatus     matlab.ui.container.Panel
        LblHR           matlab.ui.control.Label
        LblRR           matlab.ui.control.Label
        LblFiltStatus   matlab.ui.control.Label

        % Panel derecho — tabs
        TabGroup        matlab.ui.container.TabGroup

        % Tab 1: Señal
        TabSignal       matlab.ui.container.Tab
        AxOrig          matlab.ui.control.UIAxes
        AxFilt          matlab.ui.control.UIAxes
        ChkShowFilt     matlab.ui.control.CheckBox

        % Tab 2: Frecuencia
        TabFreq         matlab.ui.container.Tab
        AxFFT           matlab.ui.control.UIAxes
        AxPSD           matlab.ui.control.UIAxes
        AxSpec          matlab.ui.control.UIAxes
        BtnCalcFreq     matlab.ui.control.Button
        DdFreqSignal    matlab.ui.control.DropDown

        % Tab 3: Filtrado
        TabFilter       matlab.ui.container.Tab
        DdFiltType      matlab.ui.control.DropDown
        DdFiltDesign    matlab.ui.control.DropDown
        SpFiltOrder     matlab.ui.control.Spinner
        EfFc1           matlab.ui.control.NumericEditField
        EfFc2           matlab.ui.control.NumericEditField
        EfKaiserBeta    matlab.ui.control.NumericEditField
        LblKaiserBeta   matlab.ui.control.Label
        BtnApplyFilt    matlab.ui.control.Button
        BtnResetFilt    matlab.ui.control.Button
        AxFiltOrig      matlab.ui.control.UIAxes
        AxFiltComp      matlab.ui.control.UIAxes

        % Tab 4: Análisis ECG
        TabECG          matlab.ui.container.Tab
        ChkBaseline     matlab.ui.control.CheckBox
        ChkMuscle       matlab.ui.control.CheckBox
        ChkPowerline    matlab.ui.control.CheckBox
        ChkQRSenh       matlab.ui.control.CheckBox
        BtnApplyECG     matlab.ui.control.Button
        BtnDetectQRS    matlab.ui.control.Button
        AxQRS           matlab.ui.control.UIAxes
        AxRR            matlab.ui.control.UIAxes
        TxtResults      matlab.ui.control.TextArea
    end

    % ------------------------------------------------------------------ %
    %  PROPIEDADES DE DATOS                                                %
    % ------------------------------------------------------------------ %
    properties (Access = private)
        ecg_raw         % Datos crudos (todas las derivaciones)
        ecg_signal      % Canal activo, sin filtrar, escalado a mV
        ecg_filtered    % Señal con filtros aplicados
        Fs              % Frecuencia de muestreo
        t               % Vector de tiempo
        gain            % Ganancia ADC
        n_canales       % Número de canales
        formato         % Formato del archivo
        fname           % Nombre base del archivo

        win_i           % Índice de inicio de ventana
        win_f           % Índice de fin de ventana
        use_win         % ¿Usar ventana?
        filter_on       % ¿Filtro activo?

        R_locs          % Picos R detectados (índices globales)
        Q_locs          % Puntos Q
        S_locs          % Puntos S
        RR_ivs          % Intervalos RR (segundos)
    end

    % ================================================================== %
    %  MÉTODOS PRIVADOS — LÓGICA                                          %
    % ================================================================== %
    methods (Access = private)

        % -------------------------------------------------------------- %
        function loadFile(app)
            [file, path] = uigetfile({'*.dat','Archivos WFDB (*.dat)'}, ...
                                     'Selecciona registro ECG');
            if isequal(file, 0), return; end

            nombre   = erase(file, '.dat');
            dat_file = fullfile(path, file);
            hea_file = fullfile(path, [nombre '.hea']);

            if ~isfile(hea_file)
                uialert(app.UIFigure, ...
                    'No se encontró el .hea correspondiente.', 'Error'); return;
            end

            % --- Leer cabecera ---
            fid = fopen(hea_file, 'r');
            raw1 = fgetl(fid);
            raw2 = fgetl(fid);
            fclose(fid);

            d1 = strsplit(strtrim(raw1));
            d2 = strsplit(strtrim(raw2));

            app.n_canales = str2double(d1{2});
            app.Fs        = str2double(d1{3});
            app.formato   = str2double(d2{2});

            gain_tok = regexp(d2{3}, '[\d.]+', 'match', 'once');
            g = str2double(gain_tok);
            app.gain = max(g, 1);          % evitar división por 0

            % --- Leer datos binarios ---
            try
                if app.formato == 212
                    fid = fopen(dat_file,'r');
                    A   = double(fread(fid,'uint8'));
                    fclose(fid);
                    nb  = floor(length(A)/3)*3;
                    A   = reshape(A(1:nb), 3, [])';

                    M1 = bitshift(bitand(A(:,2),15), 8) + A(:,1);
                    M2 = bitshift(bitand(A(:,2),240), 4) + A(:,3);
                    M1(M1 >= 2048) = M1(M1 >= 2048) - 4096;
                    M2(M2 >= 2048) = M2(M2 >= 2048) - 4096;

                    tmp = zeros(2*length(M1),1);
                    tmp(1:2:end) = M1;  tmp(2:2:end) = M2;
                    app.ecg_raw = reshape(tmp, app.n_canales, [])';

                elseif app.formato == 16
                    fid = fopen(dat_file,'r');
                    raw = fread(fid,'int16');
                    fclose(fid);
                    app.ecg_raw = reshape(raw, app.n_canales, [])';

                else
                    uialert(app.UIFigure, ...
                        sprintf('Formato %d no soportado.', app.formato), 'Error');
                    return;
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Error de lectura'); return;
            end

            % --- Inicializar señal activa ---
            app.fname        = nombre;
            app.ecg_signal   = double(app.ecg_raw(:,1)) / app.gain;
            app.ecg_filtered = app.ecg_signal;
            app.t            = (0:length(app.ecg_signal)-1) / app.Fs;
            app.win_i        = 1;
            app.win_f        = length(app.ecg_signal);
            app.use_win      = false;
            app.filter_on    = false;
            app.R_locs       = [];

            % --- Actualizar UI ---
            app.LblFile.Text   = nombre;
            app.LblFs.Text     = sprintf('Fs = %d Hz', app.Fs);
            app.LblDur.Text    = sprintf('Duración = %.2f s', length(app.ecg_signal)/app.Fs);
            app.LblFormat.Text = sprintf('Formato %d  |  %d canal(es)', app.formato, app.n_canales);

            dur = length(app.ecg_signal)/app.Fs;
            app.EfWinStart.Value  = 0;
            app.EfWinEnd.Value    = dur;
            app.EfWinStart.Limits = [0, dur];
            app.EfWinEnd.Limits   = [0, dur];

            leads = arrayfun(@(x) sprintf('Canal %d', x), 1:app.n_canales, ...
                             'UniformOutput', false);
            app.DdLead.Items = leads;
            app.DdLead.Value = leads{1};

            app.LblFiltStatus.Text = 'Sin filtro aplicado';
            app.LblHR.Text  = 'FC: ---';
            app.LblRR.Text  = 'RR: ---';
            app.TxtResults.Value = {'Cargue un archivo y ejecute la detección QRS.'};

            app.plotSignal();
        end

        % -------------------------------------------------------------- %
        function plotSignal(app)
            if isempty(app.ecg_signal), return; end
            idx = app.winIdx();
            tp  = app.t(idx);
            so  = app.ecg_signal(idx);
            sf  = app.ecg_filtered(idx);

            % Original
            plot(app.AxOrig, tp, so, 'Color', [0.30 0.65 1.00], 'LineWidth', 0.8);
            app.styleAxes(app.AxOrig, 'ECG Original', 'Tiempo (s)', 'Amplitud (mV)');

            % Filtrado
            if app.ChkShowFilt.Value && app.filter_on
                plot(app.AxFilt, tp, sf, 'Color', [0.25 0.88 0.60], 'LineWidth', 0.8);
                app.styleAxes(app.AxFilt, 'ECG Filtrado', 'Tiempo (s)', 'Amplitud (mV)');
            else
                cla(app.AxFilt);
                if ~app.filter_on
                    title(app.AxFilt, 'Filtrado — (sin filtro activo)'); end
            end
        end

        % -------------------------------------------------------------- %
        function computeFreq(app)
            if isempty(app.ecg_signal), return; end
            idx = app.winIdx();

            sig = app.getSignalForFreq();
            sig = sig(idx);
            N   = length(sig);

            % --- FFT ---
            Y     = fft(sig);
            Y_mag = abs(Y(1:floor(N/2)+1)) * 2/N;
            f_ax  = (0:floor(N/2)) * app.Fs / N;

            plot(app.AxFFT, f_ax, Y_mag, 'Color',[0.30 0.65 1.00],'LineWidth',0.9);
            xlim(app.AxFFT, [0, min(100, app.Fs/2)]);
            app.styleAxes(app.AxFFT,'Espectro de Amplitud (FFT)','Frecuencia (Hz)','Amplitud  |X(f)|');

            % --- PSD Welch ---
            nfft = min(1024, 2^nextpow2(N));
            win_w = hamming(min(nfft, N));
            [pxx, fp] = pwelch(sig, win_w, [], nfft, app.Fs);

            semilogy(app.AxPSD, fp, pxx, 'Color',[1.00 0.55 0.20],'LineWidth',0.9);
            xlim(app.AxPSD, [0, min(100, app.Fs/2)]);
            app.styleAxes(app.AxPSD,'Densidad Espectral de Potencia — Welch','Frecuencia (Hz)','PSD  (V²/Hz)');

            % --- Espectrograma ---
            win_s  = min(256, floor(N/4));
            win_s  = max(win_s, 8);
            novlap = floor(win_s * 0.75);
            t_off  = app.t(app.win_i);

            [~, fs2, ts, ps] = spectrogram(sig, hamming(win_s), novlap, [], app.Fs);
            pdb = 10*log10(ps + 1e-12);
            imagesc(app.AxSpec, ts + t_off, fs2, pdb);
            axis(app.AxSpec,'xy');
            ylim(app.AxSpec,[0, min(100, app.Fs/2)]);
            colormap(app.AxSpec,'parula');

            % --- Colorbar con estilo académico consistente ---
            cb = colorbar(app.AxSpec);
            cb.Color          = [0.75 0.75 0.75];   % mismo tono que ejes
            cb.Label.String   = 'Densidad espectral (dB)';
            cb.Label.Color    = [0.75 0.75 0.75];
            cb.Label.FontSize = 8;
            cb.FontSize       = 8;
            cb.TickDirection  = 'out';

            % Título descriptivo con parámetros de análisis visibles
            ttlSpec = sprintf('Espectrograma STFT  |  ventana Hamming = %d muestras  |  solapamiento = %d%%', ...
                              win_s, round(novlap/win_s*100));
            app.styleAxes(app.AxSpec, ttlSpec, 'Tiempo (s)', 'Frecuencia (Hz)');
        end

        % -------------------------------------------------------------- %
        function applyFilter(app)
            if isempty(app.ecg_signal), return; end
            Nyq    = app.Fs / 2;
            ftype  = app.DdFiltType.Value;
            fdsgn  = app.DdFiltDesign.Value;
            order  = app.SpFiltOrder.Value;
            fc1    = app.EfFc1.Value;
            fc2    = app.EfFc2.Value;
            try
                switch ftype
                    case 'Pasa Bajos'
                        Wn = min(fc1/Nyq, 0.999);
                        [b,a] = app.makeFilt(fdsgn, order, Wn, 'low');
                    case 'Pasa Altos'
                        Wn = max(fc1/Nyq, 0.001);
                        [b,a] = app.makeFilt(fdsgn, order, Wn, 'high');
                    case 'Pasa Banda'
                        lo = min(fc1,fc2)/Nyq;  hi = max(fc1,fc2)/Nyq;
                        lo = max(lo,0.001); hi = min(hi,0.999);
                        [b,a] = app.makeFilt(fdsgn, order, [lo hi], 'bandpass');
                    case 'Notch 50 Hz'
                        [b,a] = iirnotch(50/Nyq, (50/Nyq)/35);
                    case 'Notch 60 Hz'
                        [b,a] = iirnotch(60/Nyq, (60/Nyq)/35);
                end
                app.ecg_filtered  = filtfilt(b, a, app.ecg_signal);
                app.filter_on     = true;
                if strcmp(fdsgn, 'FIR Kaiser')
                    app.LblFiltStatus.Text = sprintf('FIR Kaiser (β=%.1f) %s ord.%d aplicado', ...
                        app.EfKaiserBeta.Value, ftype, order);
                else
                    app.LblFiltStatus.Text = sprintf('%s %s ord.%d aplicado', fdsgn, ftype, order);
                end
                app.ChkShowFilt.Value  = true;
                app.plotSignal();
                app.plotFilterComparison();
            catch ME
                uialert(app.UIFigure, ME.message, 'Error en filtrado');
            end
        end

        % -------------------------------------------------------------- %
        function [b,a] = makeFilt(app, dsgn, ord, Wn, ftype)
            switch dsgn
                case 'Chebyshev I';  [b,a] = cheby1(ord, 0.5, Wn, ftype);
                case 'Chebyshev II'; [b,a] = cheby2(ord, 20,  Wn, ftype);
                case 'Elliptic';     [b,a] = ellip(ord, 0.5, 40, Wn, ftype);
                case 'FIR Kaiser'
                    beta = app.EfKaiserBeta.Value;
                    % FIR Kaiser: orden debe ser par para bandpass/notch
                    if strcmp(ftype,'bandpass') || strcmp(ftype,'bandstop')
                        if mod(ord,2) ~= 0, ord = ord + 1; end
                    end
                    win_k = kaiser(ord+1, beta);
                    switch ftype
                        case 'low';      b = fir1(ord, Wn,       'low',  win_k);
                        case 'high';     b = fir1(ord, Wn,       'high', win_k);
                        case 'bandpass'; b = fir1(ord, Wn,       'bandpass', win_k);
                        case 'bandstop'; b = fir1(ord, Wn,       'stop', win_k);
                        otherwise;       b = fir1(ord, Wn,       win_k);
                    end
                    a = 1;
                otherwise;           [b,a] = butter(ord, Wn, ftype);   % Butterworth
            end
        end

        % -------------------------------------------------------------- %
        function plotFilterComparison(app)
            if isempty(app.ecg_signal), return; end
            idx = app.winIdx();
            tp  = app.t(idx);

            plot(app.AxFiltOrig, tp, app.ecg_signal(idx), ...
                 'Color',[0.30 0.65 1.00],'LineWidth',0.8);
            app.styleAxes(app.AxFiltOrig,'Señal Original','Tiempo (s)','mV');

            if app.filter_on
                plot(app.AxFiltComp, tp, app.ecg_filtered(idx), ...
                     'Color',[0.25 0.88 0.60],'LineWidth',0.8);
                app.styleAxes(app.AxFiltComp,'Señal Filtrada','Tiempo (s)','mV');
            end
        end

        % -------------------------------------------------------------- %
        function applyECGProc(app)
            if isempty(app.ecg_signal), return; end
            sig = app.ecg_signal;
            Fs  = app.Fs;
            Nyq = Fs/2;

            if app.ChkBaseline.Value           % Baseline wander
                [b,a] = butter(4, min(0.5/Nyq,0.999), 'high');
                sig = filtfilt(b, a, sig);
            end
            if app.ChkMuscle.Value             % Ruido muscular EMG
                [b,a] = butter(4, min(40/Nyq,0.999), 'low');
                sig = filtfilt(b, a, sig);
            end
            if app.ChkPowerline.Value          % Interferencia de red 50+60 Hz
                for fn = [50, 60]
                    wo = fn/Nyq;
                    if wo < 1
                        [b,a] = iirnotch(wo, wo/35);
                        sig = filtfilt(b, a, sig);
                    end
                end
            end
            if app.ChkQRSenh.Value             % Realce QRS: BP 8-20 Hz
                lo = max(8/Nyq, 0.001);
                hi = min(20/Nyq, 0.999);
                if lo < hi
                    [b,a] = butter(2, [lo hi], 'bandpass');
                    sig = filtfilt(b, a, sig);
                end
            end

            app.ecg_filtered  = sig;
            app.filter_on     = true;
            app.ChkShowFilt.Value = true;
            app.LblFiltStatus.Text = 'Procesamiento ECG específico aplicado';
            app.plotSignal();
        end

        % -------------------------------------------------------------- %
        function detectQRS(app)
            if isempty(app.ecg_signal), return; end
            idx  = app.winIdx();
            sig  = app.ecg_filtered(idx);
            Fs   = app.Fs;
            Nyq  = Fs/2;

            % Pan-Tompkins simplificado
            % 1) Pasa-banda 5–15 Hz
            lo = max(5/Nyq, 0.001);  hi = min(15/Nyq, 0.999);
            if lo < hi
                [b,a]  = butter(3, [lo hi], 'bandpass');
                sig_bp = filtfilt(b, a, sig);
            else
                sig_bp = sig;
            end

            % 2) Derivada → cuadrado → promedio móvil
            sig_d  = [diff(sig_bp); 0];
            sig_sq = sig_d .^ 2;
            ma_win = round(0.15 * Fs);
            sig_ma = movmean(sig_sq, ma_win);

            % 3) Detección por ventanas deslizantes con normalización local
            %    Maneja cambios de amplitud en señales de estrés/ejercicio
            vent_size = 3 * Fs;                      % ventana de 3 s
            overlap   = round(0.5 * vent_size);      % solapamiento del 50 %
            mindist   = round(0.3 * Fs);
            locs_total = [];

            for vi = 1 : overlap : length(sig_ma) - vent_size
                segmento = sig_ma(vi : vi + vent_size - 1);
                max_val  = max(segmento);
                if max_val == 0, continue; end        % segmento plano → saltar

                seg_norm = segmento / max_val;        % normalización local
                [~, locs_seg] = findpeaks(seg_norm, ...
                    'MinPeakHeight',   0.5, ...
                    'MinPeakDistance', mindist);
                locs_total = [locs_total; locs_seg + vi - 1]; %#ok<AGROW>
            end

            % Eliminar duplicados generados por el solapamiento
            locs_rel = unique(locs_total);

            % 4) Refinar al máximo real de la señal original filtrada
            refwin = round(0.05 * Fs);
            R_rel  = zeros(length(locs_rel), 1);
            for k = 1:length(locs_rel)
                lo2 = max(locs_rel(k) - refwin, 1);
                hi2 = min(locs_rel(k) + refwin, length(sig));
                [~, best] = max(sig(lo2:hi2));
                R_rel(k)  = lo2 + best - 1;
            end
            R_rel = unique(R_rel);

            % Convertir a índices globales
            app.R_locs = R_rel + app.win_i - 1;

            % 5) Buscar Q y S alrededor de cada R
            qwin = round(0.1 * Fs);
            app.Q_locs = zeros(length(app.R_locs),1);
            app.S_locs = zeros(length(app.R_locs),1);
            sfull = app.ecg_filtered;

            for k = 1:length(app.R_locs)
                R   = app.R_locs(k);
                i0  = max(R - qwin, 1);
                i1  = min(R + qwin, length(sfull));
                seg = sfull(i0:i1);
                Rr  = R - i0 + 1;
                [~,qi] = min(seg(1:Rr));
                [~,si] = min(seg(Rr:end));
                app.Q_locs(k) = i0 + qi - 1;
                app.S_locs(k) = R  + si - 1;
            end

            % 6) Intervalos RR y FC
            if length(app.R_locs) > 1
                app.RR_ivs = diff(app.R_locs) / Fs;
                fc_mean    = 60 / mean(app.RR_ivs);
                app.LblHR.Text = sprintf('❤  FC: %.1f BPM', fc_mean);
                app.LblRR.Text = sprintf('RR medio: %.3f s', mean(app.RR_ivs));
            else
                app.RR_ivs = [];
                app.LblHR.Text = '❤  FC: insuf. latidos';
            end

            % 7) Graficar QRS
            R_w = app.R_locs(app.R_locs >= app.win_i & app.R_locs <= app.win_f);
            Q_w = app.Q_locs(app.Q_locs >= app.win_i & app.Q_locs <= app.win_f);
            S_w = app.S_locs(app.S_locs >= app.win_i & app.S_locs <= app.win_f);
            tp  = app.t(idx);
            sv  = app.ecg_filtered(idx);

            cla(app.AxQRS);
            plot(app.AxQRS, tp, sv, 'Color',[0.30 0.65 1.00],'LineWidth',0.8);
            hold(app.AxQRS,'on');
            if ~isempty(R_w)
                plot(app.AxQRS, app.t(R_w), app.ecg_filtered(R_w), ...
                     'rv','MarkerFaceColor','r','MarkerSize',8,'DisplayName','R');
            end
            if ~isempty(Q_w)
                plot(app.AxQRS, app.t(Q_w), app.ecg_filtered(Q_w), ...
                     'g^','MarkerFaceColor','g','MarkerSize',6,'DisplayName','Q');
            end
            if ~isempty(S_w)
                plot(app.AxQRS, app.t(S_w), app.ecg_filtered(S_w), ...
                     'ms','MarkerFaceColor','m','MarkerSize',6,'DisplayName','S');
            end
            hold(app.AxQRS,'off');
            legend(app.AxQRS,'ECG','R','Q','S','Location','best');
            app.styleAxes(app.AxQRS,'Complejos QRS Detectados','Tiempo (s)','Amplitud (mV)');

            % 8) Gráfico RR
            if ~isempty(app.RR_ivs) && ~isempty(R_w) && length(R_w) > 1
                t_rr = app.t(R_w(1:end-1));
                n    = min(length(t_rr), length(app.RR_ivs));
                plot(app.AxRR, t_rr(1:n), app.RR_ivs(1:n), ...
                     'ko-','MarkerFaceColor',[1 0.4 0.4],'LineWidth',1.2);
                app.styleAxes(app.AxRR,'Intervalos RR','Tiempo (s)','RR (s)');
            end

            % 9) Clasificación por ventanas de 5 s
            app.buildReport();
        end

        % -------------------------------------------------------------- %
        function buildReport(app)
            if isempty(app.R_locs), return; end
            Fs  = app.Fs;
            fc  = 60 / mean(app.RR_ivs);
            std_rr = std(app.RR_ivs);

            lines = {
                '═══════════════════════════════════════'
                '   ANÁLISIS ECG — RESULTADOS'
                '═══════════════════════════════════════'
                sprintf('Archivo : %s', app.fname)
                sprintf('Latidos : %d', length(app.R_locs))
                sprintf('FC media: %.1f BPM', fc)
                sprintf('RR medio: %.3f s', mean(app.RR_ivs))
                sprintf('STD  RR : %.3f s  (HRV)', std_rr)
                '───────────────────────────────────────'
                '  Ventana 5 s | BPM  | Diagnóstico'
                '───────────────────────────────────────'
            };

            vw = 5 * Fs;
            for i = app.win_i:vw:app.win_f-vw
                lw = app.R_locs(app.R_locs >= i & app.R_locs < i+vw);
                if numel(lw) > 1
                    bpm = 60 / mean(diff(lw)/Fs);
                else
                    bpm = 0;
                end
                if bpm == 0,      dx = 'Sin datos';
                elseif bpm < 60,  dx = '⬇ Bradicardia';
                elseif bpm > 100, dx = '⬆ Taquicardia';
                else,             dx = '✔ Normal';
                end
                lines{end+1} = sprintf('  %.0f–%.0f s | %5.1f | %s', ...
                    (i-1)/Fs, (i+vw-1)/Fs, bpm, dx); %#ok<AGROW>
            end
            lines{end+1} = '═══════════════════════════════════════';
            app.TxtResults.Value = lines;
        end

        % -------------------------------------------------------------- %
        function idx = winIdx(app)
            idx = app.win_i : app.win_f;
        end

        % -------------------------------------------------------------- %
        function sig = getSignalForFreq(app)
            switch app.DdFreqSignal.Value
                case 'Filtrada';  sig = app.ecg_filtered;
                otherwise;        sig = app.ecg_signal;
            end
        end

        % -------------------------------------------------------------- %
        function styleAxes(~, ax, ttl, xl, yl)
            title(ax, ttl, 'Color',[0.92 0.92 0.92],'FontWeight','bold','FontSize',10);
            xlabel(ax, xl,  'Color',[0.75 0.75 0.75],'FontSize', 9);
            ylabel(ax, yl,  'Color',[0.75 0.75 0.75],'FontSize', 9);
            grid(ax,'on');
            ax.GridColor     = [0.28 0.30 0.35];
            ax.GridAlpha     = 0.4;
            ax.XColor        = [0.70 0.70 0.70];
            ax.YColor        = [0.70 0.70 0.70];
            ax.BackgroundColor = [0.10 0.12 0.16];
        end

        % -------------------------------------------------------------- %
        function updateDesignUI(app, val)
            isKaiser = strcmp(val, 'FIR Kaiser');
            if isKaiser
                app.LblKaiserBeta.Visible = 'on';
                app.EfKaiserBeta.Visible  = 'on';
                % Sugerir orden más alto para FIR
                if app.SpFiltOrder.Value < 20
                    app.SpFiltOrder.Value = 40;
                end
            else
                app.LblKaiserBeta.Visible = 'off';
                app.EfKaiserBeta.Visible  = 'off';
                % Restaurar orden típico IIR si estaba muy alto
                if app.SpFiltOrder.Value > 12
                    app.SpFiltOrder.Value = 4;
                end
            end
        end

        % -------------------------------------------------------------- %
        function updateFiltUI(app, val)
            switch val
                case 'Pasa Bajos';  app.EfFc1.Value = 40;  app.EfFc2.Value = 0;
                case 'Pasa Altos';  app.EfFc1.Value = 0.5; app.EfFc2.Value = 0;
                case 'Pasa Banda';  app.EfFc1.Value = 0.5; app.EfFc2.Value = 40;
            end
        end

        % -------------------------------------------------------------- %
        function changeChannel(app)
            if isempty(app.ecg_raw), return; end
            ch = str2double(regexp(app.DdLead.Value,'\d+','match','once'));
            if ch >= 1 && ch <= app.n_canales
                app.ecg_signal   = double(app.ecg_raw(:,ch)) / app.gain;
                app.ecg_filtered = app.ecg_signal;
                app.filter_on    = false;
                app.LblFiltStatus.Text = 'Canal cambiado — sin filtro';
                app.plotSignal();
            end
        end

        % -------------------------------------------------------------- %
        function selectWindow(app)
            if isempty(app.ecg_signal), return; end
            ts = app.EfWinStart.Value;
            te = app.EfWinEnd.Value;
            if te <= ts
                uialert(app.UIFigure,'Fin debe ser mayor que inicio.','Error'); return;
            end
            app.win_i   = max(1, round(ts * app.Fs) + 1);
            app.win_f   = min(length(app.ecg_signal), round(te * app.Fs));
            app.use_win = true;
            app.plotSignal();
        end

        % -------------------------------------------------------------- %
        function resetWindow(app)
            if isempty(app.ecg_signal), return; end
            app.win_i   = 1;
            app.win_f   = length(app.ecg_signal);
            app.use_win = false;
            app.EfWinStart.Value = 0;
            app.EfWinEnd.Value   = length(app.ecg_signal)/app.Fs;
            app.plotSignal();
        end

        % -------------------------------------------------------------- %
        function quickFilter(app)
            if isempty(app.ecg_signal), return; end
            [b,a] = butter(4, [0.5 40]/(app.Fs/2), 'bandpass');
            app.ecg_filtered   = filtfilt(b, a, app.ecg_signal);
            app.filter_on      = true;
            app.ChkShowFilt.Value  = true;
            app.LblFiltStatus.Text = 'Filtro clínico BP 0.5–40 Hz (Butterworth ord.4)';
            app.plotSignal();
            app.plotFilterComparison();
        end

        % -------------------------------------------------------------- %
        function resetSignal(app)
            if isempty(app.ecg_signal), return; end
            app.ecg_filtered  = app.ecg_signal;
            app.filter_on     = false;
            app.LblFiltStatus.Text = 'Señal restaurada al original';
            app.plotSignal();
            cla(app.AxFiltComp);
            cla(app.AxFiltOrig);
        end

    end % methods private

    % ================================================================== %
    %  CONSTRUCCIÓN DE LA INTERFAZ                                        %
    % ================================================================== %

    % ================================================================== %
    %  CONSTRUCCIÓN DE LA INTERFAZ — v5.3 UX Mejorada                    %
    % ================================================================== %
    methods (Access = private)

        function buildUI(app)
            % ─── Paleta refinada estilo clínico-digital ───────────────
            BG_DARK  = [0.07 0.09 0.13];   % Fondo raíz  (navy muy oscuro)
            BG_PANEL = [0.11 0.14 0.20];   % Panel lateral
            BG_CARD  = [0.15 0.19 0.27];   % Tarjetas de control
            BG_FIELD = [0.20 0.24 0.33];   % Campos de entrada
            COL_TXT  = [0.92 0.93 0.96];   % Texto principal
            COL_TXT2 = [0.55 0.60 0.70];   % Texto secundario / hints
            COL_ACC  = [0.18 0.52 0.96];   % Azul acción principal
            COL_GRN  = [0.10 0.72 0.44];   % Verde confirmar/aplicar
            COL_RED  = [0.86 0.22 0.28];   % Rojo peligro/restaurar
            COL_AMB  = [0.90 0.58 0.10];   % Ámbar acceso rápido
            COL_PRP  = [0.52 0.35 0.92];   % Morado análisis espectral

            % ─── Figura principal ──────────────────────────────────────
            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [300 260 1280 680];
            app.UIFigure.Name     = 'ECG Analyzer  —  Laboratorio Virtual de Señales Biomédicas';
            app.UIFigure.Resize   = 'on';

            % ─── Layout raíz ──────────────────────────────────────────
            app.GridMain = uigridlayout(app.UIFigure,[1 2]);
            app.GridMain.ColumnWidth     = {308,'1x'};
            app.GridMain.Padding         = [10 10 10 10];
            app.GridMain.ColumnSpacing   = 10;
            app.GridMain.BackgroundColor = BG_DARK;

            % ==============================================================
            %  PANEL IZQUIERDO — CONTROLES
            % ==============================================================
            app.PanelLeft = uipanel(app.GridMain);
            app.PanelLeft.BackgroundColor = BG_PANEL;
            app.PanelLeft.BorderType      = 'none';
            app.PanelLeft.Layout.Row      = 1;
            app.PanelLeft.Layout.Column   = 1;
            try; app.PanelLeft.BorderRadius = 12; catch; end

            app.GridLeft = uigridlayout(app.PanelLeft,[5 1]);
            app.GridLeft.RowHeight       = {'fit','fit','fit','fit','1x'};
            app.GridLeft.Padding         = [10 12 10 12];
            app.GridLeft.RowSpacing      = 10;
            app.GridLeft.BackgroundColor = BG_PANEL;

            % ── ① Tarjeta: Carga de archivo ──────────────────────────
            app.PanelFile = app.mkCard(app.GridLeft, ...
                '①   CARGA DE ARCHIVO  .dat + .hea', 1, BG_CARD);
            gF = app.mkCardGrid(app.PanelFile,[6 1], ...
                {'fit','fit','fit','fit','fit','fit'});

            app.BtnLoad = app.mkBtn(gF, 1, ...
                '  Abrir Registro ECG', COL_ACC);
            app.BtnLoad.ButtonPushedFcn = @(~,~) app.loadFile();
            app.BtnLoad.Tooltip = ...
                'Selecciona un par de archivos .dat y .hea en formato WFDB/MIT-BIH';

            app.LblFile = app.mkLbl(gF, 2, ...
                '—  ningún archivo cargado  —', [0.50 0.72 1.00], 10, 'center');

            % Sub-grid para info compacta (Fs, Dur, Formato)
            gInfo = uigridlayout(gF,[3 1]);
            gInfo.Padding         = [4 2 4 2];
            gInfo.RowSpacing      = 3;
            gInfo.RowHeight       = {'fit','fit','fit'};
            gInfo.BackgroundColor = BG_CARD;
            gInfo.Layout.Row      = 3;

            app.LblFs     = app.mkLbl(gInfo,1,'Fs  =  —',[0.35 0.88 0.55],10,'left');
            app.LblDur    = app.mkLbl(gInfo,2,'Dur =  —',[0.35 0.88 0.55],10,'left');
            app.LblFormat = app.mkLbl(gInfo,3,'Formato  —',COL_TXT2, 9,'left');

            % ── ② Tarjeta: Señal y canal ────────────────────────────
            app.PanelConfig = app.mkCard(app.GridLeft, ...
                '②   SEÑAL  &  CANAL', 2, BG_CARD);
            gC = app.mkCardGrid(app.PanelConfig,[5 2], ...
                {'fit','fit','fit','fit','fit'});

            app.mkLbl2(gC,1,1,'Derivación:',COL_TXT);
            app.DdLead = uidropdown(gC);
            app.DdLead.Items           = {'Canal 1'};
            app.DdLead.BackgroundColor = BG_FIELD;
            app.DdLead.FontColor       = COL_TXT;
            app.DdLead.Layout.Row      = 1;
            app.DdLead.Layout.Column   = 2;
            app.DdLead.ValueChangedFcn = @(~,~) app.changeChannel();
            app.DdLead.Tooltip         = 'Selecciona el canal/derivación ECG a visualizar';

            sep2a = uilabel(gC);
            sep2a.Text      = 'Acciones rápidas:';
            sep2a.FontColor = COL_TXT2;
            sep2a.FontSize  = 9;
            sep2a.Layout.Row    = 2;
            sep2a.Layout.Column = [1 2];

            app.BtnQuickFilt = uibutton(gC,'push');
            app.BtnQuickFilt.Text            = '  Filtro Clínico  (0.5 – 40 Hz)';
            app.BtnQuickFilt.BackgroundColor = COL_AMB;
            app.BtnQuickFilt.FontColor       = 'white';
            app.BtnQuickFilt.FontWeight      = 'bold';
            app.BtnQuickFilt.FontSize        = 10;
            app.BtnQuickFilt.Layout.Row      = 3;
            app.BtnQuickFilt.Layout.Column   = [1 2];
            app.BtnQuickFilt.ButtonPushedFcn = @(~,~) app.quickFilter();
            app.BtnQuickFilt.Tooltip         = ...
                'Butterworth pasa-banda 0.5–40 Hz orden 4 — rango clínico estándar';
            try; app.BtnQuickFilt.CornerRadius = 6; catch; end

            app.BtnResetSig = uibutton(gC,'push');
            app.BtnResetSig.Text            = '  Restaurar Señal Original';
            app.BtnResetSig.BackgroundColor = [0.32 0.36 0.46];
            app.BtnResetSig.FontColor       = 'white';
            app.BtnResetSig.FontSize        = 10;
            app.BtnResetSig.Layout.Row      = 4;
            app.BtnResetSig.Layout.Column   = [1 2];
            app.BtnResetSig.ButtonPushedFcn = @(~,~) app.resetSignal();
            app.BtnResetSig.Tooltip         = 'Elimina todos los filtros y vuelve a la señal cruda';
            try; app.BtnResetSig.CornerRadius = 6; catch; end

            % ── ③ Tarjeta: Ventana temporal ──────────────────────────
            app.PanelWindow = app.mkCard(app.GridLeft, ...
                '③   VENTANA TEMPORAL', 3, BG_CARD);
            gW = app.mkCardGrid(app.PanelWindow,[5 2], ...
                {'fit','fit','fit','fit','fit'});

            app.mkLbl2(gW,1,1,'Inicio (s):',COL_TXT);
            app.EfWinStart = app.mkNumField(gW,1,2,0);
            app.EfWinStart.Tooltip = 'Tiempo de inicio de la ventana de análisis';

            app.mkLbl2(gW,2,1,'Fin (s):',COL_TXT);
            app.EfWinEnd = app.mkNumField(gW,2,2,0);
            app.EfWinEnd.Tooltip = 'Tiempo de fin de la ventana de análisis';

            hintW = uilabel(gW);
            hintW.Text      = 'Escribe inicio y fin para enfocar el análisis';
            hintW.FontColor = COL_TXT2;
            hintW.FontSize  = 8;
            hintW.WordWrap  = 'on';
            hintW.Layout.Row    = 3;
            hintW.Layout.Column = [1 2];

            app.BtnApplyWin = uibutton(gW,'push');
            app.BtnApplyWin.Text            = '  Aplicar Ventana';
            app.BtnApplyWin.BackgroundColor = COL_GRN;
            app.BtnApplyWin.FontColor       = 'white';
            app.BtnApplyWin.FontWeight      = 'bold';
            app.BtnApplyWin.Layout.Row      = 4;
            app.BtnApplyWin.Layout.Column   = [1 2];
            app.BtnApplyWin.ButtonPushedFcn = @(~,~) app.selectWindow();
            app.BtnApplyWin.Tooltip         = 'Aplica el recorte temporal y actualiza todos los gráficos';
            try; app.BtnApplyWin.CornerRadius = 6; catch; end

            app.BtnResetWin = uibutton(gW,'push');
            app.BtnResetWin.Text            = '  Ver Señal Completa';
            app.BtnResetWin.BackgroundColor = [0.32 0.36 0.46];
            app.BtnResetWin.FontColor       = 'white';
            app.BtnResetWin.Layout.Row      = 5;
            app.BtnResetWin.Layout.Column   = [1 2];
            app.BtnResetWin.ButtonPushedFcn = @(~,~) app.resetWindow();
            app.BtnResetWin.Tooltip         = 'Elimina la ventana y muestra toda la señal';
            try; app.BtnResetWin.CornerRadius = 6; catch; end

            % ── ④ Tarjeta: Estado en tiempo real ────────────────────
            app.PanelStatus = app.mkCard(app.GridLeft, ...
                '④   ESTADO  EN  TIEMPO  REAL', 4, BG_CARD);
            gSt = app.mkCardGrid(app.PanelStatus,[4 1], ...
                {'fit','fit','fit','1x'});

            lHRstatus = uilabel(gSt);
            lHRstatus.Text                = 'FC:  —  BPM';
            lHRstatus.FontColor           = [1.00 0.33 0.37];
            lHRstatus.FontSize            = 18;
            lHRstatus.FontWeight          = 'bold';
            lHRstatus.HorizontalAlignment = 'center';
            lHRstatus.Layout.Row          = 1;

            lRRstatus = uilabel(gSt);
            lRRstatus.Text                = 'RR medio:  —  s';
            lRRstatus.FontColor           = [0.40 0.85 1.00];
            lRRstatus.FontSize            = 12;
            lRRstatus.HorizontalAlignment = 'center';
            lRRstatus.Layout.Row          = 2;

            divSt = uilabel(gSt);
            divSt.BackgroundColor = [0.22 0.28 0.38];
            divSt.Text            = '';
            divSt.Layout.Row      = 3;

            app.LblFiltStatus = uilabel(gSt);
            app.LblFiltStatus.Text                = 'Sin filtro aplicado';
            app.LblFiltStatus.FontColor           = [0.80 0.80 0.45];
            app.LblFiltStatus.FontSize            = 9;
            app.LblFiltStatus.WordWrap            = 'on';
            app.LblFiltStatus.HorizontalAlignment = 'center';
            app.LblFiltStatus.Layout.Row          = 4;

            % ==============================================================
            %  PANEL DERECHO — TABS
            % ==============================================================
            rPanel = uipanel(app.GridMain);
            rPanel.BackgroundColor = BG_DARK;
            rPanel.BorderType      = 'none';
            rPanel.Layout.Row      = 1;
            rPanel.Layout.Column   = 2;

            app.TabGroup = uitabgroup(rPanel,'Units','normalized', ...
                'Position',[0 0 3.62 3]);
            app.TabGroup.TabLocation = 'top';

            % ============================================================
            %  TAB 1 — SEÑAL
            % ============================================================
            app.TabSignal = uitab(app.TabGroup);
            app.TabSignal.Title           = '   Señal   ';
            app.TabSignal.BackgroundColor = BG_PANEL;

            g1 = uigridlayout(app.TabSignal,[3 1]);
            g1.RowHeight       = {'fit','1x','1x'};
            g1.Padding         = [10 10 10 10];
            g1.RowSpacing      = 8;
            g1.BackgroundColor = BG_PANEL;

            ctrlRow1 = uigridlayout(g1,[1 2]);
            ctrlRow1.ColumnWidth     = {'fit','1x'};
            ctrlRow1.Padding         = [0 4 0 4];
            ctrlRow1.BackgroundColor = BG_PANEL;
            ctrlRow1.Layout.Row      = 1;

            app.ChkShowFilt = uicheckbox(ctrlRow1);
            app.ChkShowFilt.Text            = '   Mostrar señal filtrada superpuesta (verde)';
            app.ChkShowFilt.Value           = true;
            app.ChkShowFilt.FontColor       = COL_TXT;
            app.ChkShowFilt.FontSize        = 11;
            app.ChkShowFilt.Layout.Row      = 1;
            app.ChkShowFilt.Layout.Column   = 1;
            app.ChkShowFilt.ValueChangedFcn = @(~,~) app.plotSignal();
            app.ChkShowFilt.Tooltip         = ...
                'Muestra la señal filtrada en el panel inferior (requiere filtro activo)';

            app.AxOrig = uiaxes(g1);
            app.AxOrig.Layout.Row = 2;
            app.styleAxes(app.AxOrig,'ECG Original','Tiempo (s)','Amplitud (mV)');

            app.AxFilt = uiaxes(g1);
            app.AxFilt.Layout.Row = 3;
            app.styleAxes(app.AxFilt,'ECG Filtrado','Tiempo (s)','Amplitud (mV)');

            % ============================================================
            %  TAB 2 — FRECUENCIA
            % ============================================================
            app.TabFreq = uitab(app.TabGroup);
            app.TabFreq.Title           = '   Frecuencia   ';
            app.TabFreq.BackgroundColor = BG_PANEL;

            g2 = uigridlayout(app.TabFreq,[4 1]);
            g2.RowHeight       = {'fit','1x','1x','1x'};
            g2.Padding         = [10 10 10 10];
            g2.RowSpacing      = 8;
            g2.BackgroundColor = BG_PANEL;

            ctrlRow2 = uigridlayout(g2,[1 4]);
            ctrlRow2.ColumnWidth     = {'fit','fit','fit','1x'};
            ctrlRow2.Padding         = [0 4 0 4];
            ctrlRow2.ColumnSpacing   = 12;
            ctrlRow2.BackgroundColor = BG_PANEL;
            ctrlRow2.Layout.Row      = 1;

            app.BtnCalcFreq = uibutton(ctrlRow2,'push');
            app.BtnCalcFreq.Text            = '  Calcular Espectro';
            app.BtnCalcFreq.BackgroundColor = COL_PRP;
            app.BtnCalcFreq.FontColor       = 'white';
            app.BtnCalcFreq.FontWeight      = 'bold';
            app.BtnCalcFreq.Layout.Row      = 1;
            app.BtnCalcFreq.Layout.Column   = 1;
            app.BtnCalcFreq.ButtonPushedFcn = @(~,~) app.computeFreq();
            app.BtnCalcFreq.Tooltip         = ...
                'Calcula FFT, PSD Welch y Espectrograma STFT de la señal seleccionada';
            try; app.BtnCalcFreq.CornerRadius = 6; catch; end

            lddfs = uilabel(ctrlRow2);
            lddfs.Text            = 'Señal a analizar:';
            lddfs.FontColor       = COL_TXT;
            lddfs.Layout.Row      = 1;
            lddfs.Layout.Column   = 2;

            app.DdFreqSignal = uidropdown(ctrlRow2);
            app.DdFreqSignal.Items           = {'Original','Filtrada'};
            app.DdFreqSignal.Value           = 'Filtrada';
            app.DdFreqSignal.BackgroundColor = BG_FIELD;
            app.DdFreqSignal.FontColor       = COL_TXT;
            app.DdFreqSignal.Layout.Row      = 1;
            app.DdFreqSignal.Layout.Column   = 3;
            app.DdFreqSignal.Tooltip         = 'Elige si analizar la señal original o la filtrada';

            app.AxFFT = uiaxes(g2);
            app.AxFFT.Layout.Row = 2;
            app.styleAxes(app.AxFFT, ...
                'Espectro de Amplitud  (FFT)','Frecuencia (Hz)','|X(f)|');

            app.AxPSD = uiaxes(g2);
            app.AxPSD.Layout.Row = 3;
            app.styleAxes(app.AxPSD, ...
                'Densidad Espectral de Potencia  (Welch)','Frecuencia (Hz)','PSD  (V²/Hz)');

            app.AxSpec = uiaxes(g2);
            app.AxSpec.Layout.Row = 4;
            app.styleAxes(app.AxSpec, ...
                'Espectrograma  STFT','Tiempo (s)','Frecuencia (Hz)');

            % ============================================================
            %  TAB 3 — FILTRADO
            % ============================================================
            app.TabFilter = uitab(app.TabGroup);
            app.TabFilter.Title           = '   Filtrado   ';
            app.TabFilter.BackgroundColor = BG_PANEL;

            g3 = uigridlayout(app.TabFilter,[1 2]);
            g3.ColumnWidth     = {296,'1x'};
            g3.Padding         = [10 10 10 10];
            g3.ColumnSpacing   = 12;
            g3.BackgroundColor = BG_PANEL;

            filtCtrl = app.mkCard(g3,'  PARAMETROS DEL FILTRO',[1,1],BG_CARD);
            gFC = app.mkCardGrid(filtCtrl,[12 2],repmat({'fit'},1,12));

            app.mkLbl2(gFC,1,1,'Tipo de filtro:',COL_TXT);
            app.DdFiltType = uidropdown(gFC);
            app.DdFiltType.Items           = {'Pasa Bajos','Pasa Altos','Pasa Banda','Notch 50 Hz','Notch 60 Hz'};
            app.DdFiltType.BackgroundColor = BG_FIELD;
            app.DdFiltType.FontColor       = COL_TXT;
            app.DdFiltType.Layout.Row      = 1;
            app.DdFiltType.Layout.Column   = 2;
            app.DdFiltType.ValueChangedFcn = @(src,~) app.updateFiltUI(src.Value);
            app.DdFiltType.Tooltip         = ...
                'Pasa Banda: Fc1 < Fc2  |  Notch: sin frecuencia manual';

            app.mkLbl2(gFC,2,1,'Diseño:',COL_TXT);
            app.DdFiltDesign = uidropdown(gFC);
            app.DdFiltDesign.Items           = {'Butterworth','Chebyshev I','Chebyshev II','Elliptic','FIR Kaiser'};
            app.DdFiltDesign.BackgroundColor = BG_FIELD;
            app.DdFiltDesign.FontColor       = COL_TXT;
            app.DdFiltDesign.Layout.Row      = 2;
            app.DdFiltDesign.Layout.Column   = 2;
            app.DdFiltDesign.ValueChangedFcn = @(src,~) app.updateDesignUI(src.Value);
            app.DdFiltDesign.Tooltip         = ...
                'Butterworth: resp. plana  |  Cheby/Eliptico: mas selectivo  |  FIR Kaiser: fase lineal';

            app.mkLbl2(gFC,3,1,'Orden:',COL_TXT);
            app.SpFiltOrder = uispinner(gFC);
            app.SpFiltOrder.Value           = 4;
            app.SpFiltOrder.Limits          = [1 200];
            app.SpFiltOrder.Step            = 1;
            app.SpFiltOrder.BackgroundColor = BG_FIELD;
            app.SpFiltOrder.FontColor       = COL_TXT;
            app.SpFiltOrder.Layout.Row      = 3;
            app.SpFiltOrder.Layout.Column   = 2;
            app.SpFiltOrder.Tooltip         = 'IIR: 4–8 recomendado  |  FIR Kaiser: >= 20 recomendado';

            app.mkLbl2(gFC,4,1,'Fc1 / Fc corte (Hz):',COL_TXT);
            app.EfFc1 = app.mkNumField(gFC,4,2,40);
            app.EfFc1.Tooltip = 'Frecuencia de corte (o limite inferior para Pasa Banda)';

            app.mkLbl2(gFC,5,1,'Fc2 — Pasa Banda (Hz):',COL_TXT);
            app.EfFc2 = app.mkNumField(gFC,5,2,0.5);
            app.EfFc2.Tooltip = 'Limite superior para Pasa Banda (debe ser > Fc1)';

            % FIR Kaiser beta
            app.LblKaiserBeta = uilabel(gFC);
            app.LblKaiserBeta.Text      = 'beta Kaiser (atenuacion):';
            app.LblKaiserBeta.FontColor = [0.95 0.78 0.30];
            app.LblKaiserBeta.FontSize  = 10;
            app.LblKaiserBeta.Layout.Row    = 6;
            app.LblKaiserBeta.Layout.Column = 1;
            app.LblKaiserBeta.Visible   = 'off';

            app.EfKaiserBeta = uieditfield(gFC,'numeric');
            app.EfKaiserBeta.Value           = 8.6;
            app.EfKaiserBeta.Limits          = [0 20];
            app.EfKaiserBeta.BackgroundColor = BG_FIELD;
            app.EfKaiserBeta.FontColor       = [0.95 0.78 0.30];
            app.EfKaiserBeta.Layout.Row      = 6;
            app.EfKaiserBeta.Layout.Column   = 2;
            app.EfKaiserBeta.Visible         = 'off';
            app.EfKaiserBeta.Tooltip         = ...
                'b=0: rectangular | b=5.65: Hamming | b=8.6: ~60dB | b=14: ~80dB';

            divFilt = uilabel(gFC);
            divFilt.BackgroundColor = [0.22 0.27 0.37];
            divFilt.Text            = '';
            divFilt.Layout.Row      = 7;
            divFilt.Layout.Column   = [1 2];

            app.BtnApplyFilt = uibutton(gFC,'push');
            app.BtnApplyFilt.Text            = '  Aplicar Filtro';
            app.BtnApplyFilt.BackgroundColor = COL_ACC;
            app.BtnApplyFilt.FontColor       = 'white';
            app.BtnApplyFilt.FontWeight      = 'bold';
            app.BtnApplyFilt.Layout.Row      = 8;
            app.BtnApplyFilt.Layout.Column   = [1 2];
            app.BtnApplyFilt.ButtonPushedFcn = @(~,~) app.applyFilter();
            app.BtnApplyFilt.Tooltip         = 'Aplica el filtro con los parametros actuales y actualiza las graficas';
            try; app.BtnApplyFilt.CornerRadius = 6; catch; end

            app.BtnResetFilt = uibutton(gFC,'push');
            app.BtnResetFilt.Text            = '  Restaurar Señal Original';
            app.BtnResetFilt.BackgroundColor = COL_RED;
            app.BtnResetFilt.FontColor       = 'white';
            app.BtnResetFilt.Layout.Row      = 9;
            app.BtnResetFilt.Layout.Column   = [1 2];
            app.BtnResetFilt.ButtonPushedFcn = @(~,~) app.resetSignal();
            app.BtnResetFilt.Tooltip         = 'Elimina el filtro y restaura la señal cruda';
            try; app.BtnResetFilt.CornerRadius = 6; catch; end

            infoFilt = uilabel(gFC);
            infoFilt.Text = sprintf(['Nota: Para Pasa Banda ingresa Fc1 < Fc2.\n' ...
                                     'Notch no requiere frecuencia manual.\n' ...
                                     'FIR Kaiser: orden >= 20 recomendado.']);
            infoFilt.FontColor  = COL_TXT2;
            infoFilt.FontSize   = 9;
            infoFilt.WordWrap   = 'on';
            infoFilt.Layout.Row    = 10;
            infoFilt.Layout.Column = [1 2];

            filtPlots = uipanel(g3);
            filtPlots.BackgroundColor = BG_PANEL;
            filtPlots.BorderType      = 'none';
            filtPlots.Layout.Row      = 1;
            filtPlots.Layout.Column   = 2;

            gFP = uigridlayout(filtPlots,[2 1]);
            gFP.RowHeight       = {'1x','1x'};
            gFP.Padding         = [4 4 4 4];
            gFP.RowSpacing      = 8;
            gFP.BackgroundColor = BG_PANEL;

            app.AxFiltOrig = uiaxes(gFP);
            app.AxFiltOrig.Layout.Row = 1;
            app.styleAxes(app.AxFiltOrig,'Señal Original  (referencia)','Tiempo (s)','mV');

            app.AxFiltComp = uiaxes(gFP);
            app.AxFiltComp.Layout.Row = 2;
            app.styleAxes(app.AxFiltComp,'Señal Filtrada','Tiempo (s)','mV');

            % ============================================================
            %  TAB 4 — ANÁLISIS ECG
            % ============================================================
            app.TabECG = uitab(app.TabGroup);
            app.TabECG.Title           = '   Analisis ECG   ';
            app.TabECG.BackgroundColor = BG_PANEL;

            g4 = uigridlayout(app.TabECG,[1 2]);
            g4.ColumnWidth     = {296,'1x'};
            g4.Padding         = [10 10 10 10];
            g4.ColumnSpacing   = 12;
            g4.BackgroundColor = BG_PANEL;

            ecgCtrl = app.mkCard(g4,'  HERRAMIENTAS ECG',[1,1],BG_CARD);
            gEC = app.mkCardGrid(ecgCtrl,[14 1],repmat({'fit'},1,14));

            app.BtnDetectQRS = uibutton(gEC,'push');
            app.BtnDetectQRS.Text            = '  Detectar Complejos QRS';
            app.BtnDetectQRS.BackgroundColor = [0.78 0.14 0.22];
            app.BtnDetectQRS.FontColor       = 'white';
            app.BtnDetectQRS.FontWeight      = 'bold';
            app.BtnDetectQRS.FontSize        = 13;
            app.BtnDetectQRS.Layout.Row      = 1;
            app.BtnDetectQRS.ButtonPushedFcn = @(~,~) app.detectQRS();
            app.BtnDetectQRS.Tooltip         = ...
                'Deteccion Pan-Tompkins adaptada: ubica picos R, Q y S en la señal filtrada';
            try; app.BtnDetectQRS.CornerRadius = 6; catch; end

            sepE1 = uilabel(gEC);
            sepE1.Text      = 'Preprocesamiento especifico ECG:';
            sepE1.FontColor = COL_TXT2;
            sepE1.FontSize  = 9;
            sepE1.Layout.Row = 2;

            app.ChkBaseline = uicheckbox(gEC);
            app.ChkBaseline.Text      = '  Eliminar Baseline Wander  (< 0.5 Hz)';
            app.ChkBaseline.Value     = true;
            app.ChkBaseline.FontColor = COL_TXT;
            app.ChkBaseline.FontSize  = 10;
            app.ChkBaseline.Layout.Row = 3;
            app.ChkBaseline.Tooltip   = 'Elimina la deriva de linea base causada por la respiracion';

            app.ChkMuscle = uicheckbox(gEC);
            app.ChkMuscle.Text       = '  Reducir Ruido Muscular EMG  (> 40 Hz)';
            app.ChkMuscle.Value      = true;
            app.ChkMuscle.FontColor  = COL_TXT;
            app.ChkMuscle.FontSize   = 10;
            app.ChkMuscle.Layout.Row = 4;
            app.ChkMuscle.Tooltip    = 'Atenua frecuencias altas causadas por contracciones musculares';

            app.ChkPowerline = uicheckbox(gEC);
            app.ChkPowerline.Text      = '  Interferencia de Red  (50 + 60 Hz notch)';
            app.ChkPowerline.Value     = false;
            app.ChkPowerline.FontColor = COL_TXT;
            app.ChkPowerline.FontSize  = 10;
            app.ChkPowerline.Layout.Row = 5;
            app.ChkPowerline.Tooltip   = 'Aplica filtro notch en 50 Hz y 60 Hz para eliminar interferencia electrica';

            app.ChkQRSenh = uicheckbox(gEC);
            app.ChkQRSenh.Text      = '  Realzar Complejo QRS  (BP 8 – 20 Hz)';
            app.ChkQRSenh.Value     = false;
            app.ChkQRSenh.FontColor = COL_TXT;
            app.ChkQRSenh.FontSize  = 10;
            app.ChkQRSenh.Layout.Row = 6;
            app.ChkQRSenh.Tooltip   = 'Resalta el rango de frecuencia del complejo QRS para mejor deteccion';

            app.BtnApplyECG = uibutton(gEC,'push');
            app.BtnApplyECG.Text            = '  Aplicar Procesamiento ECG';
            app.BtnApplyECG.BackgroundColor = COL_GRN;
            app.BtnApplyECG.FontColor       = 'white';
            app.BtnApplyECG.FontWeight      = 'bold';
            app.BtnApplyECG.Layout.Row      = 7;
            app.BtnApplyECG.ButtonPushedFcn = @(~,~) app.applyECGProc();
            app.BtnApplyECG.Tooltip         = 'Aplica las opciones de preprocesamiento marcadas arriba';
            try; app.BtnApplyECG.CornerRadius = 6; catch; end

            sepE2 = uilabel(gEC);
            sepE2.Text      = 'Resultados del analisis:';
            sepE2.FontColor = COL_TXT2;
            sepE2.FontSize  = 9;
            sepE2.HorizontalAlignment = 'left';
            sepE2.Layout.Row = 8;

            lHRtab = uilabel(gEC);
            lHRtab.FontColor           = [1.00 0.33 0.37];
            lHRtab.FontSize            = 16;
            lHRtab.FontWeight          = 'bold';
            lHRtab.Text                = 'FC:  —  BPM';
            lHRtab.HorizontalAlignment = 'center';
            lHRtab.Layout.Row          = 9;

            lRRtab = uilabel(gEC);
            lRRtab.FontColor           = [0.40 0.85 1.00];
            lRRtab.FontSize            = 11;
            lRRtab.Text                = 'RR medio:  —  s';
            lRRtab.HorizontalAlignment = 'center';
            lRRtab.Layout.Row          = 10;

            app.LblHR = lHRtab;
            app.LblRR = lRRtab;

            app.TxtResults = uitextarea(gEC);
            app.TxtResults.Value           = {'Cargue un archivo y ejecute deteccion QRS.'};
            app.TxtResults.BackgroundColor = [0.10 0.12 0.16];
            app.TxtResults.FontColor       = [0.72 0.90 0.72];
            app.TxtResults.FontSize        = 9;
            app.TxtResults.FontName        = 'Courier New';
            app.TxtResults.Editable        = 'off';
            app.TxtResults.Layout.Row      = [11 16];

            % Graficas ECG
            ecgPlots = uipanel(g4);
            ecgPlots.BackgroundColor = BG_PANEL;
            ecgPlots.BorderType      = 'none';
            ecgPlots.Layout.Row      = 1;
            ecgPlots.Layout.Column   = 2;

            gEP = uigridlayout(ecgPlots,[2 1]);
            gEP.RowHeight       = {'2x','1x'};
            gEP.Padding         = [4 4 4 4];
            gEP.RowSpacing      = 8;
            gEP.BackgroundColor = BG_PANEL;

            app.AxQRS = uiaxes(gEP);
            app.AxQRS.Layout.Row = 1;
            app.styleAxes(app.AxQRS, ...
                'Complejos QRS Detectados','Tiempo (s)','Amplitud (mV)');

            app.AxRR = uiaxes(gEP);
            app.AxRR.Layout.Row = 2;
            app.styleAxes(app.AxRR, ...
                'Diagrama de Intervalos RR','Tiempo (s)','RR (s)');

            app.UIFigure.Visible = 'on';
        end % buildUI

        % -------------------------------------------------------------- %
        %  Helpers de construccion de UI — refinados v5.3                 %
        % -------------------------------------------------------------- %
        function p = mkCard(~, parent, title, row, bg)
            p = uipanel(parent);
            p.Title           = title;
            p.BackgroundColor = bg;
            p.ForegroundColor = [0.62 0.80 1.00];  % azul suave para titulo
            p.FontWeight      = 'bold';
            p.FontSize        = 10;
            try; p.BorderRadius = 10; catch; end     % R2022a+
            if isnumeric(row) && numel(row)==2
                p.Layout.Row    = row(1);
                p.Layout.Column = row(2);
            else
                p.Layout.Row    = row;
                p.Layout.Column = 1;
            end
        end

        function g = mkCardGrid(~, parent, dims, heights)
            g = uigridlayout(parent, dims);
            if nargin >= 4 && ~isempty(heights)
                g.RowHeight = heights;
            end
            g.Padding         = [10 8 10 10];
            g.RowSpacing      = 7;
            g.BackgroundColor = parent.BackgroundColor;
        end

        function btn = mkBtn(~, parent, row, txt, bg)
            btn = uibutton(parent,'push');
            btn.Text            = txt;
            btn.BackgroundColor = bg;
            btn.FontColor       = 'white';
            btn.FontWeight      = 'bold';
            btn.FontSize        = 11;
            btn.Layout.Row      = row;
            btn.Layout.Column   = 1;
            try; btn.CornerRadius = 6; catch; end    % R2022a+
        end

        function lbl = mkLbl(~, parent, row, txt, col, sz, align)
            lbl = uilabel(parent);
            lbl.Text                = txt;
            lbl.FontColor           = col;
            lbl.FontSize            = sz;
            lbl.HorizontalAlignment = align;
            lbl.Layout.Row          = row;
            lbl.Layout.Column       = 1;
        end

        function mkLbl2(~, parent, row, col, txt, color)
            lbl = uilabel(parent);
            lbl.Text       = txt;
            lbl.FontColor  = color;
            lbl.FontSize   = 10;
            lbl.Layout.Row = row;
            lbl.Layout.Column = col;
        end

        function ef = mkNumField(~, parent, row, col, val)
            ef = uieditfield(parent,'numeric');
            ef.Value           = val;
            ef.BackgroundColor = [0.20 0.24 0.33];
            ef.FontColor       = [0.92 0.93 0.96];
            ef.Layout.Row      = row;
            ef.Layout.Column   = col;
        end

    end % methods (UI)

    % ================================================================== %
    %  METODOS PUBLICOS                                                    %
    % ================================================================== %
    methods (Access = public)

        function app = ECGAnalyzerAppV5_3_UX ()
            buildUI(app);
            registerApp(app, app.UIFigure);
            if nargout == 0, clear app; end
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

    end

end % classdef
