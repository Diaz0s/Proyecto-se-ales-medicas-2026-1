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
[Archivo .dat/.hea]
       ↓
[Lectura WFDB]  →  Formato 212 o Formato 16
       ↓
[Normalización por ganancia]
       ↓
[Filtrado Butterworth 4° orden, 0.5–40 Hz]
       ↓
[Detección de picos R por ventanas + normalización local]
       ↓
[Identificación de complejo QRS (Q y S)]
       ↓
[Clasificación por ventanas de 5s]
   ├── BPM < 60  → Bradicardia
   ├── 60–100    → Normal
   └── BPM > 100 → Taquicardia
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

---

## Licencia

Este proyecto está bajo la Licencia MIT. Ver [`LICENSE`](LICENSE) para más detalles.
