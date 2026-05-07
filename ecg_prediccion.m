% =========================================================================
%  PREDICCIÓN EN TIEMPO REAL — CLASIFICADOR DE ARRITMIAS
%  Proyecto: Reconocimiento y Clasificación de Arritmias ECG
%
%  Descripción:
%    Carga el modelo Random Forest entrenado y lo aplica sobre un nuevo
%    registro ECG (.dat + .hea) para predecir el tipo de cada latido.
%    NO requiere archivo .atr (no supervisado en predicción).
%
%  Uso:
%    1. Tener el archivo modelo_rf_arritmias.mat generado por ecg_entrenamiento_rf.m
%    2. Ejecutar este script y seleccionar el modelo y luego el registro
% =========================================================================

clear; clc; close all;

%% ── 1. CARGAR MODELO ENTRENADO ───────────────────────────────────────────
[f_modelo, p_modelo] = uigetfile('*.mat', 'Cargar modelo Random Forest');
if isequal(f_modelo, 0), error('No seleccionaste modelo.'); end

datos_modelo = load(fullfile(p_modelo, f_modelo));
modelo    = datos_modelo.modelo;
MS_ANTES  = datos_modelo.MS_ANTES;
MS_DESPUES = datos_modelo.MS_DESPUES;

fprintf('✓ Modelo cargado: %s\n', f_modelo);
fprintf('  Clases: %s\n', strjoin(datos_modelo.CLASES_INCLUIR, ', '));
fprintf('  Accuracy de entrenamiento: %.2f%%\n\n', datos_modelo.acc);

%% ── 2. SELECCIONAR REGISTRO A PREDECIR ───────────────────────────────────
[file, path] = uigetfile('*.dat', 'Selecciona registro ECG a predecir');
if isequal(file, 0), error('No seleccionaste archivo.'); end

nombre   = erase(file, '.dat');
dat_file = fullfile(path, file);
hea_file = fullfile(path, nombre + ".hea");

%% ── 3. LEER Y PREPROCESAR ────────────────────────────────────────────────
fid = fopen(hea_file, 'r');
l1  = fgetl(fid); l2 = fgetl(fid);
fclose(fid);

d1 = strsplit(l1); d2 = strsplit(l2);
n_canales = str2double(d1{2});
Fs        = str2double(d1{3});
formato   = str2double(d2{2});
gain      = str2double(d2{3});

if formato == 212
    fid = fopen(dat_file,'r'); A = fread(fid,'uint8'); fclose(fid);
    A   = double(A(1:floor(length(A)/3)*3));
    A   = reshape(A,3,[])';
    M1  = bitshift(bitand(A(:,2),15),8)  + A(:,1);
    M2  = bitshift(bitand(A(:,2),240),4) + A(:,3);
    M1(M1>=2048) = M1(M1>=2048)-4096;
    M2(M2>=2048) = M2(M2>=2048)-4096;
    et = zeros(2*length(M1),1);
    et(1:2:end)=M1; et(2:2:end)=M2;
    data = reshape(et,n_canales,[])';
elseif formato == 16
    fid=fopen(dat_file,'r'); data=fread(fid,'int16'); fclose(fid);
    data=reshape(data,n_canales,[])';
else
    error('Formato no soportado: %d', formato);
end

ecg = data(:,1);
if ~isnan(gain) && gain ~= 0, ecg = ecg / gain; end
t = (0:length(ecg)-1)/Fs;

[b,a]    = butter(4,[0.5 40]/(Fs/2),'bandpass');
ecg_filt = filtfilt(b,a,ecg);

%% ── 4. DETECCIÓN DE PICOS R ──────────────────────────────────────────────
ventana  = 3*Fs; overlap = round(0.5*ventana);
locs_total = [];

for i = 1:overlap:length(ecg_filt)-ventana
    seg     = ecg_filt(i:i+ventana-1);
    mx      = max(abs(seg));
    if mx == 0, continue; end
    [~,locs] = findpeaks(seg/mx,'MinPeakHeight',0.5,'MinPeakDistance',round(0.3*Fs));
    locs_total = [locs_total; locs+i-1]; %#ok<AGROW>
end
locs_total = unique(locs_total);
fprintf('Picos R detectados: %d\n', length(locs_total));

%% ── 5. EXTRAER FEATURES Y PREDECIR ──────────────────────────────────────
m_antes   = round(MS_ANTES  / 1000 * Fs);
m_despues = round(MS_DESPUES / 1000 * Fs);

predicciones = cell(length(locs_total), 1);
confianzas   = zeros(length(locs_total), 1);
feat_matrix  = [];

for k = 1:length(locs_total)
    R   = locs_total(k);
    ini = R - m_antes;
    fin = R + m_despues;
    if ini < 1 || fin > length(ecg_filt), continue; end

    seg  = ecg_filt(ini:fin);
    feat = extraer_features_pred(seg, R-ini+1, Fs, locs_total, k, m_antes);
    feat_matrix = [feat_matrix; feat]; %#ok<AGROW>

    [pred, scores] = predict(modelo, feat);
    predicciones{k} = pred{1};
    confianzas(k)   = max(scores);
end

%% ── 6. VISUALIZACIÓN ─────────────────────────────────────────────────────
colores_clase = containers.Map( ...
    {'N',  'L',  'R',  'A',  'V',  'otro'}, ...
    {'g',  'b',  'c',  'm',  'r',  'k'  } );

H   = min(1800, round(length(t)/Fs)) * Fs;
idx = 1:H;

figure('Name','Predicción de arritmias','Position',[50 50 1200 500])
plot(t(idx), ecg_filt(idx), 'Color',[0.4 0.6 0.9])
hold on

clases_unicas = unique(predicciones(~cellfun(@isempty, predicciones)));
handles_leyenda = [];
labels_leyenda  = {};

for c = clases_unicas'
    cls   = c{1};
    color = 'k';
    if isKey(colores_clase, cls), color = colores_clase(cls); end

    idx_cls = find(strcmp(predicciones, cls));
    idx_cls = idx_cls(locs_total(idx_cls) <= H);

    if ~isempty(idx_cls)
        h = plot(locs_total(idx_cls)/Fs, ecg_filt(locs_total(idx_cls)), ...
            'o', 'Color', color, 'MarkerFaceColor', color, 'MarkerSize', 7);
        handles_leyenda(end+1) = h;
        labels_leyenda{end+1}  = cls;
    end
end

legend(handles_leyenda, labels_leyenda, 'Location', 'best')
title(sprintf('Predicción de Arritmias — Registro %s', nombre))
xlabel('Tiempo (s)'); ylabel('Amplitud (mV)'); grid on

%% ── 7. RESUMEN EN CONSOLA ────────────────────────────────────────────────
fprintf('\n=== Resumen de predicción — Registro %s ===\n', nombre);
todas_preds = predicciones(~cellfun(@isempty, predicciones));
total = length(todas_preds);

for c = clases_unicas'
    n   = sum(strcmp(todas_preds, c{1}));
    pct = 100 * n / total;
    fprintf('  %-6s : %5d latidos  (%5.1f%%)\n', c{1}, n, pct);
end
fprintf('  %-6s : %5d latidos\n', 'TOTAL', total);

%% ── 8. CLASIFICACIÓN POR VENTANAS DE 5 SEGUNDOS ─────────────────────────
fprintf('\n=== Clasificación por ventanas de 5s ===\n');
fprintf('%-30s %-10s %-12s %-6s\n', 'Ventana (s)', 'BPM', 'Arritmia dom.', 'Conf.');
fprintf('%s\n', repmat('-', 1, 60));

ventana_clas = 5 * Fs;
for i = 1:ventana_clas:length(ecg_filt)-ventana_clas
    idx_win = find(locs_total >= i & locs_total < i+ventana_clas);

    if numel(idx_win) > 1
        RR  = diff(locs_total(idx_win)) / Fs;
        BPM = 60 / mean(RR);
    else
        BPM = 0;
    end

    if ~isempty(idx_win)
        preds_win = predicciones(idx_win);
        preds_win = preds_win(~cellfun(@isempty, preds_win));
        if ~isempty(preds_win)
            clases_win = unique(preds_win);
            counts_win = cellfun(@(c) sum(strcmp(preds_win,c)), clases_win);
            [~, im]    = max(counts_win);
            arritmia   = clases_win{im};
            conf_media = mean(confianzas(idx_win(confianzas(idx_win)>0)));
        else
            arritmia = '?'; conf_media = 0;
        end
    else
        arritmia = 'Sin datos'; conf_media = 0;
    end

    fprintf('%.1f – %.1f s              %6.1f     %-12s  %.2f\n', ...
        (i-1)/Fs, (i+ventana_clas-1)/Fs, BPM, arritmia, conf_media);
end

% =========================================================================
%  FUNCIÓN AUXILIAR (copia reducida de extraer_features para predicción)
% =========================================================================
function feat = extraer_features_pred(seg, R_rel, Fs, locs, k, m_antes) %#ok<DEFNU>
    N    = length(seg);
    f1   = max(seg);   f2 = min(seg);    f3  = f1-f2;
    f4   = mean(seg);  f5 = std(seg);    f6  = skewness(seg);
    f7   = kurtosis(seg);               f8  = mean(seg.^2);
    f9   = sum(abs(diff(sign(seg))))/N;
    dentro = abs(seg) > 0.3*abs(f1);
    f10  = sum(dentro)/Fs*1000;

    RR_prev = calcular_rr_pred(locs, k, -1, Fs);
    RR_sig  = calcular_rr_pred(locs, k, +1, Fs);
    RR_prom = RR_prev;
    for j = max(1,k-5):k-1
        RR_prom = RR_prom + abs(locs(k)-locs(j))/Fs*1000/(k-j);
    end
    RR_prom = RR_prom / max(min(5,k-1)+1,1);
    f11=RR_prev; f12=RR_sig; f13=RR_prom;
    f14=RR_prev/max(RR_sig,1); f15=RR_prev/max(RR_prom,1);

    NFFT = 256;
    Sf   = abs(fft(seg-mean(seg),NFFT)).^2; Sf=Sf(1:NFFT/2+1);
    fr   = (0:NFFT/2)*Fs/NFFT;
    Pt   = sum(Sf(fr>=0.5&fr<40)); if Pt==0, Pt=eps; end
    f16  = sum(Sf(fr>=0.5&fr< 5))/Pt;
    f17  = sum(Sf(fr>= 5&fr<15))/Pt;
    f18  = sum(Sf(fr>=15&fr<40))/Pt;
    [~,id]=max(Sf); f19=fr(min(id,length(fr)));

    f20=max(diff(seg(1:R_rel)));
    f21=min(diff(seg(R_rel:end)));
    f22=trapz(max(seg,0)); f23=trapz(abs(seg));

    feat=[f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 ...
          f11 f12 f13 f14 f15 f16 f17 f18 f19 f20 f21 f22 f23];
end

function rr = calcular_rr_pred(locs, k, dir, Fs)
    j = k+dir;
    if j>=1 && j<=length(locs)
        rr = abs(locs(k)-locs(j))/Fs*1000;
    else
        rr = 800;
    end
end
