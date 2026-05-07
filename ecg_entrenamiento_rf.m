% =========================================================================
%  ENTRENAMIENTO: CLASIFICADOR DE ARRITMIAS ECG — RANDOM FOREST
%  Proyecto: Reconocimiento y Clasificación de Arritmias ECG
%
%  Descripción:
%    Extrae features por latido desde registros MIT-BIH (usando anotaciones
%    .atr como etiquetas ground truth) y entrena un clasificador Random
%    Forest (TreeBagger) para reconocer tipos de arritmia.
%
%  Flujo:
%    1. Seleccionar carpeta con registros MIT-BIH (.dat + .hea + .atr)
%    2. Procesar múltiples registros → extraer features por latido
%    3. Entrenar Random Forest con validación cruzada
%    4. Evaluar con matriz de confusión y métricas
%    5. Guardar modelo entrenado (.mat)
%
%  Dependencias:
%    Signal Processing Toolbox  (butter, filtfilt)
%    Statistics and ML Toolbox  (TreeBagger, confusionchart)
%
%  Registros MIT-BIH recomendados (señal limpia):
%    100, 101, 103, 105, 106, 108, 109, 111, 112, 113,
%    114, 115, 116, 117, 119, 121, 122, 123, 124
% =========================================================================

clear; clc; close all;

%% ── CONFIGURACIÓN GLOBAL ─────────────────────────────────────────────────

% Registros a procesar (sin extensión)
% Usar registros con señal limpia — evitar 102, 104 (marcapasos), 118 (ruidoso)
REGISTROS = {'100','101','103','105','106','108','109', ...
             '111','112','113','114','115','116','117', ...
             '119','121','122','123','124'};

% Clases a incluir (símbolos MIT-BIH más frecuentes)
% N=Normal, L=LBBB, R=RBBB, A=APC, V=PVC, /=Paced, ~=Noise
CLASES_INCLUIR = {'N','L','R','A','V'};

% Parámetros del modelo
N_ARBOLES     = 100;   % Número de árboles en el bosque
MIN_HOJAS     = 5;     % Mínimo de muestras por hoja
PROP_TEST     = 0.2;   % 20% para test, 80% para entrenamiento

% Ventana de feature por latido: ±N ms alrededor del pico R
MS_ANTES = 150;   % ms antes del pico R
MS_DESPUES = 250; % ms después del pico R

fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║   CLASIFICADOR DE ARRITMIAS — RANDOM FOREST      ║\n');
fprintf('╚══════════════════════════════════════════════════╝\n\n');

%% ── 1. SELECCIÓN DE CARPETA ──────────────────────────────────────────────
carpeta = uigetdir('', 'Selecciona carpeta con archivos MIT-BIH (.dat .hea .atr)');
if isequal(carpeta, 0)
    error('No seleccionaste carpeta.');
end

fprintf('Carpeta: %s\n', carpeta);
fprintf('Registros a procesar: %d\n\n', length(REGISTROS));

%% ── 2. EXTRACCIÓN DE FEATURES ────────────────────────────────────────────
% Para cada registro → para cada latido anotado → extraer vector de features

todas_features = [];
todas_etiquetas = {};

for r = 1:length(REGISTROS)

    reg = REGISTROS{r};
    dat_file = fullfile(carpeta, [reg '.dat']);
    hea_file = fullfile(carpeta, [reg '.hea']);
    atr_file = fullfile(carpeta, [reg '.atr']);

    % Verificar que existan los tres archivos
    if ~isfile(dat_file) || ~isfile(hea_file) || ~isfile(atr_file)
        fprintf('[SKIP] Registro %s: archivos no encontrados\n', reg);
        continue
    end

    fprintf('[%02d/%02d] Procesando registro %s... ', r, length(REGISTROS), reg);

    try
        %% 2.1 Leer .hea
        fid = fopen(hea_file, 'r');
        linea1 = fgetl(fid);
        linea2 = fgetl(fid);
        fclose(fid);

        d1 = strsplit(linea1);
        d2 = strsplit(linea2);

        n_canales = str2double(d1{2});
        Fs        = str2double(d1{3});
        formato   = str2double(d2{2});
        gain      = str2double(d2{3});

        %% 2.2 Leer señal .dat
        if formato == 212
            fid = fopen(dat_file, 'r');
            A   = fread(fid, 'uint8');
            fclose(fid);

            A  = double(A(1:floor(length(A)/3)*3));
            A  = reshape(A, 3, [])';

            M1 = bitshift(bitand(A(:,2),15),8)  + A(:,1);
            M2 = bitshift(bitand(A(:,2),240),4) + A(:,3);
            M1(M1 >= 2048) = M1(M1 >= 2048) - 4096;
            M2(M2 >= 2048) = M2(M2 >= 2048) - 4096;

            ecg_total          = zeros(2*length(M1), 1);
            ecg_total(1:2:end) = M1;
            ecg_total(2:2:end) = M2;
            data = reshape(ecg_total, n_canales, [])';

        elseif formato == 16
            fid  = fopen(dat_file, 'r');
            data = fread(fid, 'int16');
            fclose(fid);
            data = reshape(data, n_canales, [])';
        else
            fprintf('Formato %d no soportado — skip\n', formato);
            continue
        end

        ecg = data(:,1);
        if ~isnan(gain) && gain ~= 0
            ecg = ecg / gain;
        end

        %% 2.3 Filtrado Butterworth 0.5–40 Hz
        [b, a]   = butter(4, [0.5 40]/(Fs/2), 'bandpass');
        ecg_filt = filtfilt(b, a, ecg);

        %% 2.4 Leer anotaciones .atr (formato binario WFDB)
        [ann_muestras, ann_simbolos] = leer_atr(atr_file);

        %% 2.5 Extraer features por latido
        muestras_antes  = round(MS_ANTES  / 1000 * Fs);
        muestras_despues = round(MS_DESPUES / 1000 * Fs);
        n_beat = muestras_antes + muestras_despues + 1; % longitud del segmento

        n_latidos_reg = 0;

        for k = 1:length(ann_muestras)

            simbolo = ann_simbolos{k};

            % Filtrar solo las clases de interés
            if ~ismember(simbolo, CLASES_INCLUIR)
                continue
            end

            R = ann_muestras(k);

            % Verificar límites
            ini = R - muestras_antes;
            fin = R + muestras_despues;
            if ini < 1 || fin > length(ecg_filt)
                continue
            end

            % Segmento centrado en el pico R
            seg = ecg_filt(ini:fin);

            % ── VECTOR DE FEATURES ──────────────────────────────────────
            feat = extraer_features(seg, R - ini + 1, Fs, ...
                                    ann_muestras, k, muestras_antes, muestras_despues);

            todas_features  = [todas_features;  feat];       %#ok<AGROW>
            todas_etiquetas = [todas_etiquetas; {simbolo}];  %#ok<AGROW>
            n_latidos_reg   = n_latidos_reg + 1;
        end

        fprintf('%d latidos extraídos\n', n_latidos_reg);

    catch ME
        fprintf('ERROR: %s\n', ME.message);
    end
end

fprintf('\nTotal de latidos: %d\n', size(todas_features, 1));
fprintf('Clases detectadas:\n');
for c = CLASES_INCLUIR
    n = sum(strcmp(todas_etiquetas, c{1}));
    fprintf('  %-5s → %d latidos\n', c{1}, n);
end

if isempty(todas_features)
    error('No se extrajeron features. Verificar rutas y archivos .atr.');
end

%% ── 3. PREPARACIÓN DEL DATASET ───────────────────────────────────────────
fprintf('\n── Preparando dataset ──\n');

etiquetas_cat = categorical(todas_etiquetas);
X = todas_features;
Y = etiquetas_cat;

% División train/test estratificada
rng(42);  % Semilla para reproducibilidad
idx_test = false(length(Y), 1);

for c = categories(Y)'
    idx_c    = find(Y == c{1});
    n_test_c = max(1, round(length(idx_c) * PROP_TEST));
    sel      = idx_c(randperm(length(idx_c), n_test_c));
    idx_test(sel) = true;
end

X_train = X(~idx_test, :);
Y_train = Y(~idx_test);
X_test  = X(idx_test, :);
Y_test  = Y(idx_test);

fprintf('Train: %d muestras | Test: %d muestras\n', ...
    length(Y_train), length(Y_test));

%% ── 4. ENTRENAMIENTO RANDOM FOREST ──────────────────────────────────────
fprintf('\n── Entrenando Random Forest (%d árboles) ──\n', N_ARBOLES);
tic

modelo = TreeBagger(N_ARBOLES, X_train, Y_train, ...
    'Method',          'classification', ...
    'MinLeafSize',     MIN_HOJAS, ...
    'NumPredictorsToSample', 'auto', ...   % sqrt(n_features) por defecto
    'OOBPrediction',   'on', ...           % Error out-of-bag para monitoreo
    'OOBPredictorImportance', 'on');       % Importancia de features

t_entreno = toc;
fprintf('Entrenamiento completado en %.1f s\n', t_entreno);

%% ── 5. EVALUACIÓN ────────────────────────────────────────────────────────
fprintf('\n── Evaluación en conjunto de test ──\n');

[pred_test, scores_test] = predict(modelo, X_test);
pred_cat = categorical(pred_test);

% Matriz de confusión
figure('Name', 'Matriz de Confusión', 'Position', [100 100 700 600])
confusionchart(Y_test, pred_cat, ...
    'Title', 'Matriz de Confusión — Random Forest', ...
    'RowSummary', 'row-normalized', ...
    'ColumnSummary', 'column-normalized');

% Métricas globales
acc = mean(pred_cat == Y_test) * 100;
fprintf('Accuracy global: %.2f%%\n\n', acc);

% Métricas por clase
clases_presentes = categories(Y_test);
fprintf('%-6s %-12s %-12s %-12s\n', 'Clase', 'Sensibilidad', 'Precisión', 'F1-Score');
fprintf('%s\n', repmat('-', 1, 44));

for c = clases_presentes'
    cls   = c{1};
    VP    = sum(Y_test == cls & pred_cat == cls);
    FN    = sum(Y_test == cls & pred_cat ~= cls);
    FP    = sum(Y_test ~= cls & pred_cat == cls);

    sens  = VP / max(VP + FN, 1);
    prec  = VP / max(VP + FP, 1);
    f1    = 2 * sens * prec / max(sens + prec, eps);

    fprintf('%-6s %-12.3f %-12.3f %-12.3f\n', cls, sens, prec, f1);
end

%% ── 6. ERROR OOB Y CURVA DE CONVERGENCIA ────────────────────────────────
figure('Name', 'Error OOB')
plot(oobError(modelo), 'b-', 'LineWidth', 2)
xlabel('Número de árboles')
ylabel('Error OOB')
title('Convergencia del Random Forest (Error Out-of-Bag)')
grid on

%% ── 7. IMPORTANCIA DE FEATURES ──────────────────────────────────────────
nombres_feat = nombres_features();

importancia = modelo.OOBPermutedPredictorDeltaError;
[imp_ord, idx_ord] = sort(importancia, 'descend');

figure('Name', 'Importancia de Features', 'Position', [100 100 800 500])
barh(imp_ord(end:-1:1))
yticks(1:length(imp_ord))
yticklabels(nombres_feat(idx_ord(end:-1:1)))
xlabel('Importancia (reducción OOB)')
title('Importancia de Features — Random Forest')
grid on

%% ── 8. GUARDAR MODELO ────────────────────────────────────────────────────
[archivo_guardar, ruta_guardar] = uiputfile('*.mat', ...
    'Guardar modelo entrenado', 'modelo_rf_arritmias.mat');

if ~isequal(archivo_guardar, 0)
    ruta_completa = fullfile(ruta_guardar, archivo_guardar);
    save(ruta_completa, 'modelo', 'CLASES_INCLUIR', 'Fs', ...
         'MS_ANTES', 'MS_DESPUES', 'N_ARBOLES', 'acc');
    fprintf('\nModelo guardado en: %s\n', ruta_completa);
    fprintf('Accuracy final: %.2f%%\n', acc);
end

fprintf('\n✓ Pipeline completado.\n');

% =========================================================================
%  FUNCIONES AUXILIARES
% =========================================================================

function [muestras, simbolos] = leer_atr(atr_file)
% Lee un archivo de anotaciones MIT-BIH en formato binario WFDB.
% Retorna vectores de posiciones de muestra y símbolos de anotación.
%
% Formato: cada anotación ocupa 2 bytes
%   Byte bajo  + (6 bits bajos del byte alto) = tiempo diferencial
%   2 bits altos del byte alto = tipo de anotación (codificado)

    fid  = fopen(atr_file, 'r');
    data = fread(fid, 'uint16', 'ieee-le');
    fclose(fid);

    % Tabla de códigos WFDB → símbolo ECG
    codigo_simbolo = containers.Map( ...
        {1,  2,  3,  4,  5,  6,  7,  8,  9,  10, ...
         11, 12, 13, 14, 15, 16, 17, 18, 19, 20, ...
         21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 38, 41}, ...
        {'N','L','R','a','V','F','J','A','S','E', ...
         'j','/','"','~','+','Q','(',')','^','|', ...
         'x','(',')','{','}','n','N','u','?','!','[',']','e','E','/','f'} ...
    );

    muestras = [];
    simbolos = {};
    t_actual = 0;

    for i = 1:length(data)
        val  = data(i);
        tipo = bitshift(val, -10);      % 6 bits altos
        dt   = bitand(val, 1023);       % 10 bits bajos

        if tipo == 0 && dt == 0
            break  % Fin del archivo
        end

        if tipo == 59  % SKIP: siguiente word es tiempo largo
            if i+1 <= length(data)
                t_actual = t_actual + data(i+1);
            end
            continue
        end

        t_actual = t_actual + dt;

        if isKey(codigo_simbolo, tipo)
            sym = codigo_simbolo(tipo);
            % Solo guardar latidos (no marcadores de ritmo ni ruido)
            if ~ismember(sym, {'(',')','{','}','+','"','~','|','^'})
                muestras(end+1) = t_actual;  %#ok<AGROW>
                simbolos{end+1} = sym;       %#ok<AGROW>
            end
        end
    end
end


function feat = extraer_features(seg, R_rel, Fs, ann_muestras, k, m_antes, m_despues)
% Extrae un vector de features numéricas de un segmento de latido.
%
% Features extraídas (23 en total):
%   Morfológicas (del segmento):
%     1.  Amplitud máxima del pico R
%     2.  Amplitud mínima (valle Q o S)
%     3.  Rango pico-a-pico
%     4.  Media del segmento
%     5.  Desviación estándar
%     6.  Asimetría (skewness)
%     7.  Curtosis
%     8.  Energía del segmento (RMS²)
%     9.  Cruce por cero normalizado
%     10. Duración del QRS estimada (ms)
%   Intervalos RR:
%     11. RR previo (ms)
%     12. RR siguiente (ms)
%     13. RR promedio local (ms)
%     14. Ratio RR_prev / RR_sig
%     15. Ratio RR_prev / RR_prom
%   Frecuencias (FFT del segmento):
%     16. Potencia en banda 0.5–5 Hz
%     17. Potencia en banda 5–15 Hz
%     18. Potencia en banda 15–40 Hz
%     19. Frecuencia dominante
%   Forma de la onda:
%     20. Pendiente máxima antes del pico R
%     21. Pendiente máxima después del pico R
%     22. Área bajo la curva (parte positiva)
%     23. Área bajo la curva (valor absoluto)

    N = length(seg);

    % ── Features morfológicas ──
    f1  = max(seg);                          % Amplitud pico R
    f2  = min(seg);                          % Amplitud mínima
    f3  = f1 - f2;                           % Rango pico-a-pico
    f4  = mean(seg);                         % Media
    f5  = std(seg);                          % Desviación estándar
    f6  = skewness(seg);                     % Asimetría
    f7  = kurtosis(seg);                     % Curtosis
    f8  = mean(seg.^2);                      % Energía (RMS²)
    f9  = sum(abs(diff(sign(seg)))) / N;     % Cruce por cero normalizado

    % Duración del QRS: región donde |seg| > 30% del pico R
    umbral_qrs = 0.3 * abs(f1);
    dentro_qrs = abs(seg) > umbral_qrs;
    duracion_qrs = sum(dentro_qrs) / Fs * 1000;  % en ms
    f10 = duracion_qrs;

    % ── Intervalos RR ──
    RR_prev = calcular_rr(ann_muestras, k, -1, Fs);
    RR_sig  = calcular_rr(ann_muestras, k, +1, Fs);

    % RR promedio local (los 5 latidos anteriores)
    RR_prom = 0;
    n_prom  = 0;
    for j = max(1,k-5):k-1
        rr = (ann_muestras(k) - ann_muestras(j)) / Fs * 1000 / (k-j);
        RR_prom = RR_prom + rr;
        n_prom  = n_prom + 1;
    end
    if n_prom > 0
        RR_prom = RR_prom / n_prom;
    else
        RR_prom = RR_prev;
    end

    f11 = RR_prev;
    f12 = RR_sig;
    f13 = RR_prom;
    f14 = RR_prev / max(RR_sig,  1);
    f15 = RR_prev / max(RR_prom, 1);

    % ── Features espectrales (FFT) ──
    NFFT = 256;
    Sf   = abs(fft(seg - mean(seg), NFFT)).^2;
    Sf   = Sf(1:NFFT/2+1);
    freqs = (0:NFFT/2) * Fs / NFFT;

    P_baja  = sum(Sf(freqs >= 0.5 & freqs <  5));
    P_media = sum(Sf(freqs >=  5  & freqs < 15));
    P_alta  = sum(Sf(freqs >= 15  & freqs < 40));
    P_total = P_baja + P_media + P_alta;

    f16 = P_baja  / max(P_total, eps);  % Potencia relativa baja
    f17 = P_media / max(P_total, eps);  % Potencia relativa media
    f18 = P_alta  / max(P_total, eps);  % Potencia relativa alta

    [~, idx_dom] = max(Sf);
    f19 = freqs(min(idx_dom, length(freqs)));   % Frecuencia dominante

    % ── Forma de la onda (pendiente y área) ──
    pre_R  = seg(1:R_rel);
    post_R = seg(R_rel:end);

    f20 = max(diff(pre_R));           % Pendiente máxima subida
    f21 = min(diff(post_R));          % Pendiente máxima bajada (negativa)
    f22 = trapz(max(seg, 0));         % Área positiva
    f23 = trapz(abs(seg));            % Área absoluta

    feat = [f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 ...
            f11 f12 f13 f14 f15 ...
            f16 f17 f18 f19 ...
            f20 f21 f22 f23];
end


function rr_ms = calcular_rr(ann_muestras, k, direccion, Fs)
% Calcula el intervalo RR en ms hacia el latido anterior (dir=-1) o siguiente (dir=+1)
    idx_vecino = k + direccion;
    if idx_vecino >= 1 && idx_vecino <= length(ann_muestras)
        rr_ms = abs(ann_muestras(k) - ann_muestras(idx_vecino)) / Fs * 1000;
    else
        rr_ms = 800;  % Valor por defecto (75 bpm)
    end
end


function nombres = nombres_features()
% Retorna los nombres de las 23 features para los gráficos
    nombres = {
        'Amp. pico R',       'Amp. mínima',        'Rango p-p', ...
        'Media',             'Std',                 'Asimetría', ...
        'Curtosis',          'Energía RMS²',        'Cruces por cero', ...
        'Duración QRS',      'RR previo',           'RR siguiente', ...
        'RR promedio',       'RR_prev/RR_sig',      'RR_prev/RR_prom', ...
        'Pot. baja (<5Hz)',  'Pot. media (5-15Hz)', 'Pot. alta (15-40Hz)', ...
        'Frec. dominante',   'Pendiente subida',    'Pendiente bajada', ...
        'Área positiva',     'Área absoluta'
    };
end
