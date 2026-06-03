# 🫀 Reconocimiento y Clasificación de Arritmias ECG

[![MATLAB](https://img.shields.io/badge/MATLAB-R2021b+-orange?logo=mathworks)](https://www.mathworks.com/)
[![Dataset](https://img.shields.io/badge/Dataset-MIT--BIH%20Arrhythmia-blue)](https://physionet.org/content/mitdb/1.0.0/)
[![Status](https://img.shields.io/badge/Estado-En%20Desarrollo-yellow)]()
[![License](https://img.shields.io/badge/Licencia-MIT-green)](LICENSE)

> Proyecto académico de procesamiento de señales biomédicas para la detección y clasificación automática de arritmias cardíacas a partir de señales ECG, usando la base de datos MIT-BIH Arrhythmia Database.

---

## 📋 Tabla de Contenidos

| # | Sección | Descripción |
|---|---------|-------------|
| 1 | [Descripción del Proyecto](#descripción-del-proyecto) | Contexto, objetivo y alcance |
| 2 | [Estructura del Repositorio](#estructura-del-repositorio) | Mapa de carpetas y archivos |
| 3 | [Documentación](#documentación) | Acceso a todos los documentos |
| 4 | [Dataset](#dataset) | Información sobre MIT-BIH |
| 5 | [Implementación](#implementación) | Código y pipeline de procesamiento |
| 6 | [Resultados](#resultados) | Hallazgos preliminares y finales |
| 7 | [Requisitos](#requisitos) | Herramientas necesarias |
| 8 | [Uso](#uso) | Cómo ejecutar el proyecto |
| 9 | [Autores](#autores) | Información del equipo |

---

## Descripción del Proyecto

Este proyecto implementa un sistema de reconocimiento y clasificación de arritmias cardíacas a partir de señales electrocardiográficas (ECG). El pipeline incluye:

- **Lectura** de archivos binarios en formato WFDB (`.dat` + `.hea`) de la base MIT-BIH
- **Preprocesamiento** mediante filtrado Butterworth banda-paso (0.5–40 Hz)
- **procesamiento** modificable mediante diferentes tipos de filtros
- **Detección** de picos R y complejo QRS mediante análisis por ventanas
- **Clasificación** del ritmo cardíaco: Normal, Bradicardia y Taquicardia

### Objetivo General
Desarrollar un sistema automático en MATLAB capaz de procesar señales ECG crudas e identificar patrones de arritmia cardíaca con base en intervalos RR y frecuencia cardíaca instantánea.

---

## Estructura del Repositorio

```
ecg-arritmias/
│
├── README.md                          ← Este archivo (moderador)
│
├── docs/                              ← Documentación del proyecto
│   ├── 1_reporte_fundamentacion.md    ← Marco teórico y justificación
│   ├── 2_matriz_comparativa.md        ← Comparación de alternativas tecnológicas
│   ├── 3_ficha_tecnica_dataset.md     ← Ficha técnica MIT-BIH Arrhythmia Database
│   └── 4_documento_disenio_tecnico.md ← Diseño del sistema y decisiones de arquitectura
│
├── src/                               ← Código fuente MATLAB
│   └── ecg_clasificador.m             ← Script principal de procesamiento
│
├── evidencias/                        ← Capturas y evidencias de implementación
│   ├── fig_ecg_crudo.png
│   ├── fig_ecg_filtrado.png
│   ├── fig_deteccion_picos.png
│   └── README_evidencias.md
│
├── resultados/                        ← Salidas y métricas del sistema
│   ├── preliminares/
│   │   └── resultados_preliminares.md
│   └── finales/
│       └── resultados_finales.md
│
└── data/                              ← (NO incluido en el repo - ver instrucciones)
    └── README_data.md                 ← Instrucciones para obtener el dataset
```

---

## Documentación

| Documento | Descripción | Enlace |
|-----------|-------------|--------|
| 📄 Reporte de Fundamentación | Marco teórico: ECG, arritmias, procesamiento de señales | [Ver](docs/1_reporte_fundamentacion.md) |
| 📊 Matriz Comparativa | Comparación de herramientas, algoritmos y bases de datos | [Ver](docs/2_matriz_comparativa.md) |
| 🗂️ Ficha Técnica del Dataset | Descripción detallada de MIT-BIH Arrhythmia Database | [Ver](docs/3_ficha_tecnica_dataset.md) |
| 🛠️ Documento de Diseño Técnico | Arquitectura del sistema, decisiones y justificaciones | [Ver](docs/4_documento_disenio_tecnico.md) |

---

## Dataset

**MIT-BIH Arrhythmia Database** — PhysioNet  
- 48 registros de ECG de 30 minutos a 360 Hz  
- Formato WFDB: archivos `.dat` (binario) + `.hea` (cabecera)  
- Anotaciones de cardiólogos expertos disponibles en `.atr`

> ⚠️ El dataset **no está incluido** en este repositorio por su tamaño. Ver [`data/README_data.md`](data/README_data.md) para instrucciones de descarga.

---

## Implementación

### Pipeline de Procesamiento

```
┌────────────────────────────────────────────┐
│ 1. ADQUISICIÓN DE DATOS ECG                │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
         Archivo WFDB (.dat + .hea)
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 2. LECTURA Y DECODIFICACIÓN                │
├────────────────────────────────────────────┤
│ • Lectura del archivo .hea                 │
│ • Obtención de Fs                          │
│ • Obtención del número de canales          │
│ • Obtención del formato (212 o 16 bits)    │
│ • Obtención de la ganancia ADC             │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 3. RECONSTRUCCIÓN DE LA SEÑAL              │
├────────────────────────────────────────────┤
│ Formato 212                               │
│ • Separación de muestras empaquetadas      │
│ • Conversión a valores con signo           │
│                                            │
│ Formato 16                                │
│ • Lectura directa int16                    │
│ • Conversión a matriz multicanal           │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 4. ESCALAMIENTO FISIOLÓGICO                │
├────────────────────────────────────────────┤
│ ECG(mV)=ADC/Gain                           │
│                                            │
│ Conversión de cuentas digitales            │
│ a milivoltios clínicos                     │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 5. SELECCIÓN DE DERIVACIÓN                 │
├────────────────────────────────────────────┤
│ Canal 1                                    │
│ Canal 2                                    │
│ ...                                        │
│ Canal N                                    │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 6. SELECCIÓN DE VENTANA TEMPORAL           │
├────────────────────────────────────────────┤
│ t_inicio                                   │
│ t_fin                                      │
│                                            │
│ Reduce la región de análisis               │
│ para procesamiento local                   │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
              ECG DE TRABAJO
┌────────────────────────────────────────────┐
│ 7. PREPROCESAMIENTO ECG                    │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

    ┌─────────────────────────────┐
    │ Eliminación Baseline Wander │
    │ HPF Butterworth 0.5 Hz      │
    └──────────────┬──────────────┘
                   │
                   ▼

    ┌─────────────────────────────┐
    │ Reducción Ruido Muscular    │
    │ LPF Butterworth 40 Hz       │
    └──────────────┬──────────────┘
                   │
                   ▼

    ┌─────────────────────────────┐
    │ Eliminación Red Eléctrica   │
    │ Notch 50 Hz                 │
    │ Notch 60 Hz                 │
    └──────────────┬──────────────┘
                   │
                   ▼

    ┌─────────────────────────────┐
    │ Realce del Complejo QRS     │
    │ BandPass 8–20 Hz            │
    └──────────────┬──────────────┘
                   │
                   ▼

          ECG PREPROCESADO
┌────────────────────────────────────────────┐
│ 8. DISEÑO DEL FILTRO                       │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

Tipo de filtro
│
├── Pasa Bajos
├── Pasa Altos
├── Pasa Banda
├── Notch 50 Hz
└── Notch 60 Hz

                      │
                      ▼

Método de diseño
│
├── Butterworth
├── Chebyshev I
├── Chebyshev II
├── Elíptico
└── FIR Kaiser

                      │
                      ▼

Generación de coeficientes
b[n], a[n]

                      │
                      ▼

Filtrado de fase cero
filtfilt(b,a,x)

                      │
                      ▼

ECG FILTRADO
┌────────────────────────────────────────────┐
│ 9. ANÁLISIS ESPECTRAL                      │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

                ECG

        ┌───────┼─────────┐
        │       │         │
        ▼       ▼         ▼

      FFT     PSD      STFT
               │
               │
               ▼

 FFT
 • Frecuencias dominantes
 • Armónicos

 PSD Welch
 • Potencia por banda
 • Distribución energética

 STFT
 • Evolución temporal
 • Mapa tiempo-frecuencia
┌────────────────────────────────────────────┐
│ 10. DETECCIÓN QRS                          │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

BandPass 5-15 Hz

                      │
                      ▼

Derivada

s'(n)

                      │
                      ▼

Cuadrado

[s'(n)]²

                      │
                      ▼

Integración móvil

movmean()

150 ms

                      │
                      ▼

Normalización local

ventanas de 3 s

                      │
                      ▼

Detección adaptativa

findpeaks()

                      │
                      ▼

Refinamiento

máximo real ECG

                      │
                      ▼

Picos R
┌────────────────────────────────────────────┐
│ 11. EXTRACCIÓN DE PARÁMETROS               │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

R_locs

                      │
                      ▼

RR = diff(R_locs)/Fs

                      │
                      ▼

FC = 60/RR

                      │
                      ▼

RR medio

                      │
                      ▼

STD(RR)

(HRV básica)
┌────────────────────────────────────────────┐
│ 12. CLASIFICACIÓN                          │
└─────────────────────┬──────────────────────┘
                      │
                      ▼

Ventanas de 5 segundos

                      │
                      ▼

BPM local

                      │
      ┌───────────────┼───────────────┐
      ▼               ▼               ▼

 BPM < 60       60 ≤ BPM ≤100     BPM > 100

 Bradicardia       Normal          Taquicardia
┌────────────────────────────────────────────┐
│ 13. VISUALIZACIÓN Y REPORTE                │
└────────────────────────────────────────────┘

• ECG original
• ECG filtrado
• Comparación antes/después
• FFT
• PSD Welch
• Espectrograma
• Detección QRS
• Intervalos RR
• Frecuencia cardíaca media
• Variabilidad RR (HRV)
• Diagnóstico automático
• Reporte textual final
```

### Archivos del proyecto

| Script | Descripción |
|--------|-------------|
| [`src/ecg_clasificador.m`](src/ecg_clasificador.m) | Lectura, filtrado, detección QRS y clasificación por umbrales de BPM |
| [`src/ecg_entrenamiento_rf.m`](src/ecg_entrenamiento_rf.m) | Extracción de 23 features por latido + entrenamiento Random Forest con anotaciones `.atr` |
| [`src/ecg_prediccion.m`](src/ecg_prediccion.m) | Carga el modelo entrenado y predice latido a latido en nuevos registros |

### Features extraídas por latido (23 total)

| Categoría | Features |
|-----------|---------|
| **Morfológicas** | Amplitud R, mínimo, rango, media, std, skewness, kurtosis, energía, cruces por cero, duración QRS |
| **Intervalos RR** | RR previo, RR siguiente, RR promedio local, ratios RR |
| **Espectrales** | Potencia relativa en 3 bandas, frecuencia dominante |
| **Forma de onda** | Pendiente de subida/bajada, área positiva, área absoluta |

---

## Resultados

- 📁 [Resultados Preliminares](resultados/preliminares/resultados_preliminares.md)
- 📁 [Resultados Finales](resultados/finales/resultados_finales.md)
- 🖼️ [Evidencias de Implementación](evidencias/README_evidencias.md)

---

## Requisitos

- **MATLAB** R2021b o superior
- **Signal Processing Toolbox** (para `butter`, `filtfilt`, `findpeaks`)
- Archivos `.dat` y `.hea` de MIT-BIH (ver instrucciones de descarga)

---

## Uso

```matlab
% 1. Abrir MATLAB y navegar a la carpeta src/
cd src/

% 2. Ejecutar el script principal
ecg_clasificador

% 3. En el cuadro de diálogo, seleccionar un archivo .dat de MIT-BIH
% El script detectará automáticamente el .hea correspondiente

% 4. Revisar las figuras generadas y la consola para la clasificación por ventanas
```

---

## Autores

BRIWER POLO 
OSCAR DIAZ
ANDRES ROMERO

2026


