% =========================================================================
%  RECONOCIMIENTO Y CLASIFICACIÓN DE ARRITMIAS ECG
%  Proyecto: Procesamiento de Señales Médicas
%
%  Descripción:
%    Lee archivos ECG en formato WFDB (.dat + .hea) de la base MIT-BIH,
%    aplica preprocesamiento, detecta picos R, identifica el complejo QRS
%    y clasifica el ritmo cardíaco en ventanas de tiempo.
%
%  Dataset requerido:
%    MIT-BIH Arrhythmia Database — https://physionet.org/content/mitdb/1.0.0/
%
%  Dependencias MATLAB:
%    Signal Processing Toolbox (butter, filtfilt, findpeaks)
%
%  Uso:
%    Ejecutar el script. Se abrirá un diálogo para seleccionar el .dat.
%    El .hea debe estar en la misma carpeta con el mismo nombre base.
% =========================================================================

clear; clc; close all;

%% ── 1. SELECCIÓN DE ARCHIVO ──────────────────────────────────────────────
[file, path] = uigetfile('*.dat', 'Selecciona archivo ECG (MIT-BIH)');

if isequal(file, 0)
    error('No seleccionaste archivo.');
end

nombre   = erase(file, '.dat');
dat_file = fullfile(path, file);
hea_file = fullfile(path, nombre + ".hea");

%% ── 2. LECTURA DEL ARCHIVO .HEA ─────────────────────────────────────────
% El .hea contiene metadatos en texto plano:
%   Línea 1: [nombre] [n_canales] [Fs] [n_muestras]
%   Línea 2: [archivo] [formato] [ganancia] [bits] ...

fid = fopen(hea_file, 'r');
if fid == -1
    error('No se encontró el archivo .hea: %s', hea_file);
end

linea1 = fgetl(fid);
linea2 = fgetl(fid);
fclose(fid);

datos1 = strsplit(linea1);
datos2 = strsplit(linea2);

n_canales = str2double(datos1{2});
Fs        = str2double(datos1{3});
formato   = str2double(datos2{2});
gain      = str2double(datos2{3});

fprintf('=== Información del registro ===\n');
fprintf('Archivo  : %s\n', nombre);
fprintf('Formato  : %d\n', formato);
fprintf('Fs       : %d Hz\n', Fs);
fprintf('Canales  : %d\n', n_canales);
fprintf('Ganancia : %.1f ADC/mV\n', gain);

%% ── 3. LECTURA Y DECODIFICACIÓN DE LA SEÑAL ─────────────────────────────
if formato == 212
    % Formato 212: cada 3 bytes almacenan 2 muestras de 12 bits
    fid = fopen(dat_file, 'r');
    A   = fread(fid, 'uint8');
    fclose(fid);

    A  = double(A(1:floor(length(A)/3)*3));
    A  = reshape(A, 3, [])';

    % Reconstrucción de muestras de 12 bits
    M1 = bitshift(bitand(A(:,2), 15), 8) + A(:,1);
    M2 = bitshift(bitand(A(:,2), 240), 4) + A(:,3);

    % Complemento a dos para valores negativos
    M1(M1 >= 2048) = M1(M1 >= 2048) - 4096;
    M2(M2 >= 2048) = M2(M2 >= 2048) - 4096;

    % Intercalar las dos muestras
    ecg_total         = zeros(2*length(M1), 1);
    ecg_total(1:2:end) = M1;
    ecg_total(2:2:end) = M2;

    data = reshape(ecg_total, n_canales, [])';

elseif formato == 16
    % Formato 16: enteros de 16 bits sin compresión
    fid  = fopen(dat_file, 'r');
    data = fread(fid, 'int16');
    fclose(fid);

    data = reshape(data, n_canales, [])';

else
    error('Formato no soportado: %d', formato);
end

%% ── 4. EXTRACCIÓN Y NORMALIZACIÓN ───────────────────────────────────────
% Usar canal 1 (MLII en la mayoría de registros MIT-BIH)
ecg = data(:, 1);

% Convertir de unidades ADC a milivoltios
if ~isnan(gain) && gain ~= 0
    ecg = ecg / gain;
end

t = (0:length(ecg)-1) / Fs;
fprintf('Duración total: %.2f segundos\n\n', length(ecg)/Fs);

%% ── 5. VISUALIZACIÓN ECG CRUDO ──────────────────────────────────────────
% Mostrar solo los primeros 30 minutos (o menos si el archivo es más corto)
H   = 1800;
idx = 1:round(min(H, length(t)/Fs) * Fs);

figure('Name', 'ECG Crudo')
plot(t(idx), ecg(idx))
title('Señal ECG Original')
xlabel('Tiempo (s)')
ylabel('Amplitud (mV)')
grid on

%% ── 6. FILTRADO ─────────────────────────────────────────────────────────
% Filtro Butterworth pasa-banda:
%   - Corte inferior 0.5 Hz: elimina deriva de línea base (respiración)
%   - Corte superior 40 Hz : elimina ruido EMG y artefactos de alta frecuencia
%   - filtfilt: aplicación en dos pasadas → fase cero (sin desplazamiento)
[b, a]    = butter(4, [0.5 40]/(Fs/2), 'bandpass');
ecg_filt  = filtfilt(b, a, ecg);

figure('Name', 'ECG Filtrado')
plot(t(idx), ecg_filt(idx))
title('Señal ECG Filtrada (Butterworth 4°, 0.5–40 Hz)')
xlabel('Tiempo (s)')
ylabel('Amplitud (mV)')
grid on

%% ── 7. DETECCIÓN DE PICOS R ─────────────────────────────────────────────
% Estrategia: ventanas deslizantes con 50% de solapamiento
% Normalización local permite adaptarse a variaciones de amplitud

ventana_det = 3 * Fs;               % Ventana de 3 segundos
overlap     = round(0.5 * ventana_det);  % 50% de solapamiento
locs_total  = [];

for i = 1:overlap:length(ecg_filt) - ventana_det

    segmento = ecg_filt(i:i + ventana_det - 1);
    max_val  = max(abs(segmento));

    if max_val == 0
        continue
    end

    seg_norm = segmento / max_val;  % Normalización local

    [~, locs] = findpeaks(seg_norm, ...
        'MinPeakHeight',   0.5, ...         % 50% del máximo local
        'MinPeakDistance', round(0.3*Fs));  % Mínimo 300 ms entre picos (BPM < 200)

    locs_total = [locs_total; locs + i - 1]; %#ok<AGROW>
end

% Eliminar duplicados generados por el solapamiento
locs_total = unique(locs_total);

figure('Name', 'Detección de Picos R')
plot(t(idx), ecg_filt(idx))
hold on
% Solo mostrar los picos que están dentro del rango visualizado
locs_vis = locs_total(locs_total >= idx(1) & locs_total <= idx(end));
plot(locs_vis/Fs, ecg_filt(locs_vis), 'ro', 'MarkerSize', 6, 'LineWidth', 1.5)
title('Detección de Picos R')
xlabel('Tiempo (s)')
ylabel('Amplitud (mV)')
legend('ECG filtrado', 'Picos R detectados')
grid on

%% ── 8. DETECCIÓN DEL COMPLEJO QRS ───────────────────────────────────────
% Para cada pico R, buscar Q (mínimo anterior) y S (mínimo posterior)
% dentro de una ventana de ±150 ms

ventana_qrs = round(0.15 * Fs);  % 150 ms en muestras
Q_locs = zeros(length(locs_total), 1);
S_locs = zeros(length(locs_total), 1);

for k = 1:length(locs_total)

    R   = locs_total(k);
    ini = max(R - ventana_qrs, 1);
    fin = min(R + ventana_qrs, length(ecg_filt));

    segmento = ecg_filt(ini:fin);
    R_rel    = R - ini + 1;

    % Q: mínimo en la región pre-R
    [~, q_idx] = min(segmento(1:R_rel));
    Q_locs(k) = ini + q_idx - 1;

    % S: mínimo en la región post-R
    [~, s_idx] = min(segmento(R_rel:end));
    S_locs(k) = R + s_idx - 1;
end

%% ── 9. CLASIFICACIÓN POR VENTANAS DE 5 SEGUNDOS ─────────────────────────
% Para cada ventana no solapada de 5s:
%   1. Recoger los picos R en la ventana
%   2. Calcular BPM promedio a partir de intervalos RR
%   3. Clasificar según umbrales clínicos estándar

ventana_clas = 5 * Fs;
estados = strings(0);
tiempos = [];

fprintf('=== Clasificación por ventanas ===\n');
fprintf('%-30s %-10s %-15s\n', 'Ventana (s)', 'BPM', 'Estado');
fprintf('%s\n', repmat('-', 1, 55));

for i = 1:ventana_clas:length(ecg_filt) - ventana_clas

    locs_win = locs_total(locs_total >= i & locs_total < i + ventana_clas);

    if numel(locs_win) > 1
        RR  = diff(locs_win) / Fs;  % Intervalos RR en segundos
        BPM = 60 / mean(RR);
    else
        BPM = 0;
    end

    if BPM == 0
        estado = "Sin datos";
    elseif BPM < 60
        estado = "Bradicardia";
    elseif BPM > 100
        estado = "Taquicardia";
    else
        estado = "Normal";
    end

    estados(end+1) = estado; %#ok<AGROW>
    tiempos(end+1) = (i-1)/Fs; %#ok<AGROW>

    fprintf('%.1f – %.1f s              %6.1f        %s\n', ...
        (i-1)/Fs, (i+ventana_clas-1)/Fs, BPM, estado);
end

%% ── 10. RESUMEN FINAL ───────────────────────────────────────────────────
fprintf('\n=== Resumen de clasificación ===\n');
for etiqueta = ["Normal", "Bradicardia", "Taquicardia", "Sin datos"]
    n = sum(estados == etiqueta);
    fprintf('  %-15s : %d ventanas (%.1f%%)\n', etiqueta, n, 100*n/length(estados));
end
