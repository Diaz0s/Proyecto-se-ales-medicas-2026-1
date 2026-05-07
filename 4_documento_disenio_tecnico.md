# 🛠️ Documento de Diseño Técnico
## Reconocimiento y Clasificación de Arritmias ECG

> **⚠️ PLANTILLA** — Completar con los detalles específicos de implementación del equipo.

---

## 1. Visión General del Sistema

El sistema recibe como entrada archivos binarios WFDB (`.dat` + `.hea`) de la base MIT-BIH y produce como salida una clasificación temporal del ritmo cardíaco en ventanas de 5 segundos.

### Diagrama de bloques del pipeline

```
┌─────────────────────────────────────────────────────────┐
│                    ENTRADA                              │
│           Archivo .dat + .hea (MIT-BIH)                 │
└────────────────────────┬────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│              BLOQUE 1: LECTURA WFDB                    │
│  • Parseo del .hea → Fs, ganancia, formato, canales    │
│  • Decodificación binaria del .dat (Formato 212/16)    │
│  • Conversión a mV mediante división por ganancia      │
└────────────────────────┬───────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│            BLOQUE 2: PREPROCESAMIENTO                  │
│  • Filtro Butterworth 4° orden, pasa-banda 0.5–40 Hz  │
│  • Aplicación con filtfilt (fase cero)                │
└────────────────────────┬───────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│           BLOQUE 3: DETECCIÓN DE PICOS R               │
│  • Segmentación en ventanas de 3s (50% solapamiento)  │
│  • Normalización local por valor máximo absoluto      │
│  • findpeaks: MinPeakHeight=0.5, MinPeakDistance=0.3s │
│  • Fusión de locs con unique()                        │
└────────────────────────┬───────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│          BLOQUE 4: DETECCIÓN COMPLEJO QRS              │
│  • Ventana de búsqueda: ±150 ms alrededor de cada R   │
│  • Q: mínimo en el segmento previo al pico R          │
│  • S: mínimo en el segmento posterior al pico R       │
└────────────────────────┬───────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│           BLOQUE 5: CLASIFICACIÓN                      │
│  • Ventanas de 5 segundos sin solapamiento            │
│  • Cálculo BPM = 60 / mean(diff(R_locs)/Fs)          │
│  • BPM < 60 → Bradicardia                            │
│  • 60 ≤ BPM ≤ 100 → Normal                          │
│  • BPM > 100 → Taquicardia                           │
└────────────────────────┬───────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────┐
│                    SALIDAS                             │
│  • Figura: ECG crudo                                  │
│  • Figura: ECG filtrado                               │
│  • Figura: ECG con picos R marcados                   │
│  • Consola: tabla de clasificación por ventana        │
└────────────────────────────────────────────────────────┘
```

---

## 2. Especificaciones de Cada Bloque

### 2.1 Bloque 1 — Lectura WFDB

**Entrada:** Rutas de archivos `.dat` y `.hea`  
**Salida:** Matriz `data` [N_muestras × N_canales] en mV, parámetros `Fs`, `gain`

**Formato 212 — Algoritmo de decodificación:**
```
Cada 3 bytes [A, B, C] contienen 2 muestras de 12 bits:
  Muestra 1 = (nibble bajo de B) << 8 | A
  Muestra 2 = (nibble alto de B) << 4 | C
  Signo: si valor ≥ 2048 → valor = valor - 4096
```

**Parámetros parseados del .hea:**
- Línea 1: `[nombre] [n_canales] [Fs] [n_muestras]`
- Línea 2: `[archivo] [formato] [ganancia] [bits] [offset] ...`

---

### 2.2 Bloque 2 — Preprocesamiento

**Filtro:** Butterworth pasa-banda  
**Orden:** 4  
**Frecuencia de corte inferior:** 0.5 Hz (elimina deriva de línea base)  
**Frecuencia de corte superior:** 40 Hz (elimina ruido EMG y red eléctrica)  
**Método de aplicación:** `filtfilt` (fase cero — sin desplazamiento temporal)

**Código MATLAB:**
```matlab
[b, a] = butter(4, [0.5 40]/(Fs/2), 'bandpass');
ecg_filt = filtfilt(b, a, ecg);
```

**Justificación del rango 0.5–40 Hz:**
- La energía del complejo QRS se concentra entre 5–40 Hz
- Las ondas P y T tienen componentes hasta ~20 Hz
- La deriva de línea base se encuentra por debajo de 0.5 Hz

---

### 2.3 Bloque 3 — Detección de Picos R

**Estrategia:** Detección por ventanas con normalización local

| Parámetro | Valor | Justificación |
|-----------|-------|---------------|
| Tamaño de ventana | 3 × Fs muestras | Compromiso entre contexto y adaptabilidad |
| Solapamiento | 50% | Evita pérdida de picos en bordes de ventana |
| MinPeakHeight | 0.5 (normalizado) | Equivale al 50% del máximo local |
| MinPeakDistance | 0.3 × Fs | Mínimo fisiológico (BPM máx ≈ 200) |
| Fusión de detecciones | `unique()` | Elimina duplicados por solapamiento |

**Consideraciones:**
- La normalización local por `max(abs(segmento))` permite adaptar el umbral a variaciones de amplitud entre pacientes y derivaciones.
- El solapamiento de 50% garantiza que ningún pico R quede sin detección por estar en el borde de una ventana.

---

### 2.4 Bloque 4 — Complejo QRS

**Ventana de búsqueda:** ±150 ms alrededor del pico R (equivale a ±`round(0.15 * Fs)` muestras)

| Punto | Criterio de detección |
|-------|----------------------|
| **Q** | Mínimo en el segmento `[R - 150ms, R]` |
| **R** | Pico detectado en Bloque 3 |
| **S** | Mínimo en el segmento `[R, R + 150ms]` |

**Limitaciones conocidas:**
- En latidos con morfología atípica (PVC, LBBB), el mínimo puede no corresponder al Q/S real.
- No se implementa validación de amplitud ni duración del QRS en esta versión.

---

### 2.5 Bloque 5 — Clasificación

**Ventana de análisis:** 5 segundos sin solapamiento  
**Métrica:** BPM promedio de la ventana = `60 / mean(diff(R_locs_ventana) / Fs)`

| Condición | Clasificación |
|-----------|--------------|
| < 2 picos R en ventana | "Sin datos" |
| BPM < 60 | "Bradicardia" |
| 60 ≤ BPM ≤ 100 | "Normal" |
| BPM > 100 | "Taquicardia" |

**Nota:** Los umbrales de 60 y 100 bpm son los estándares clínicos internacionales para definición de bradicardia y taquicardia sinusal.

---

## 3. Parámetros Configurables

| Parámetro | Variable MATLAB | Valor actual | Rango típico |
|-----------|----------------|-------------|-------------|
| F. corte inferior (Hz) | `0.5` | 0.5 | 0.1 – 1.0 |
| F. corte superior (Hz) | `40` | 40 | 30 – 50 |
| Orden del filtro | `4` | 4 | 2 – 8 |
| Ventana detección (s) | `3` | 3 | 2 – 5 |
| Solapamiento detección | `0.5` | 50% | 25 – 75% |
| MinPeakHeight | `0.5` | 0.5 | 0.3 – 0.7 |
| MinPeakDistance (s) | `0.3` | 0.3 | 0.2 – 0.4 |
| Ventana QRS (s) | `0.15` | 0.15 | 0.1 – 0.2 |
| Ventana clasificación (s) | `5` | 5 | 3 – 10 |

---

## 4. Limitaciones y Trabajo Futuro

### 4.1 Limitaciones actuales
- Solo clasifica Bradicardia, Normal y Taquicardia (3 clases simples)
- No usa las anotaciones `.atr` para validación cuantitativa
- Sin manejo de artefactos de movimiento
- Procesamiento offline (no tiempo real)
- Solo usa el Canal 1 (MLII)

### 4.2 Trabajo futuro propuesto
- [ ] Implementar algoritmo Pan-Tompkins para mayor robustez en detección de QRS
- [ ] Comparar resultados con anotaciones `.atr` (sensibilidad y especificidad)
- [ ] Agregar clasificación de PVC y fibrilación auricular (análisis de variabilidad RR)
- [ ] Implementar clasificador de ML (SVM o Random Forest) sobre features de HRV
- [ ] Extender a procesamiento de Canal 2 (V5)
- [ ] Exportar resultados a archivo CSV para análisis estadístico

---

## 5. Entorno de Desarrollo

| Componente | Versión |
|-----------|---------|
| MATLAB | R2021b o superior |
| Signal Processing Toolbox | Requerida |
| Sistema operativo | Windows / Linux / macOS |
| Formato de datos | WFDB v10.x |

---

*Documento elaborado por: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*  
*Fecha: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*
