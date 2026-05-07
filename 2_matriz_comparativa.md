# 📊 Matriz Comparativa de Alternativas
## Reconocimiento y Clasificación de Arritmias ECG

> **⚠️ PLANTILLA** — Completar con la justificación de las elecciones tecnológicas del equipo.

---

## 1. Comparativa de Bases de Datos ECG

| Criterio | **MIT-BIH Arrhythmia** ✅ | PTB Diagnostic | European ST-T | AHA Database |
|---------|--------------------------|---------------|--------------|-------------|
| **Acceso** | Gratuito (PhysioNet) | Gratuito (PhysioNet) | Gratuito (PhysioNet) | Licencia paga |
| **N° registros** | 48 | 549 | 90 | 80 |
| **Duración** | 30 min/registro | 2 min/registro | 2 h/registro | 3 h/registro |
| **Fs (Hz)** | 360 | 1000 | 250 | 250 |
| **Anotaciones** | ✅ Detalladas | ✅ Diagnóstico | ✅ ST-T | ✅ Expertos |
| **Arritmias** | Alta variedad | Diagnósticos clínicos | Isquemia | Arritmias ventriculares |
| **Estándar en literatura** | ✅ Sí (gold standard) | Parcial | Parcial | Parcial |
| **Formato** | WFDB | WFDB | WFDB | WFDB |
| **Uso en este proyecto** | ✅ **Seleccionada** | ❌ | ❌ | ❌ |

**Justificación de selección:** MIT-BIH es la base de datos de referencia mundial para evaluación de algoritmos de detección de arritmias, con la mayor diversidad de patologías anotadas y amplia documentación en la literatura científica.

---

## 2. Comparativa de Herramientas de Procesamiento

| Criterio | **MATLAB** ✅ | Python (SciPy/NumPy) | R | LabVIEW |
|---------|-------------|---------------------|---|---------|
| **Licencia** | Comercial/Académica | Open source | Open source | Comercial |
| **Signal Processing Toolbox** | ✅ Nativo | Requiere SciPy | Requiere paquetes | ✅ Nativo |
| **Lectura WFDB** | Manual / WFDB Toolbox | ✅ wfdb-python | Limitado | Limitado |
| **Visualización** | ✅ Integrada | Matplotlib / Plotly | ggplot2 | ✅ Integrada |
| **Facilidad para filtros IIR** | ✅ Alta | Alta | Media | Alta |
| **Documentación biomédica** | ✅ Amplia | ✅ Amplia | Media | Media |
| **Prototipado rápido** | Alta | Alta | Media | Baja |
| **Costo** | Medio-Alto | Gratuito | Gratuito | Alto |
| **Uso en este proyecto** | ✅ **Seleccionada** | ❌ | ❌ | ❌ |

**Justificación de selección:** MATLAB provee Signal Processing Toolbox integrado con funciones nativas como `butter`, `filtfilt` y `findpeaks`, reduciendo el tiempo de implementación. Además, es el entorno estándar en cursos de ingeniería biomédica.

---

## 3. Comparativa de Algoritmos de Detección de Picos R

| Criterio | **Umbral adaptativo + ventanas** ✅ | Pan-Tompkins (1985) | Wavelet | CNN/Deep Learning |
|---------|-------------------------------------|-------------------|---------|-------------------|
| **Complejidad de implementación** | Baja | Media | Alta | Muy alta |
| **Requerimiento computacional** | Bajo | Bajo | Medio | Alto |
| **Sensibilidad a ruido** | Media | Alta | Alta | Alta |
| **Requiere entrenamiento** | No | No | No | Sí |
| **Interpretabilidad** | Alta | Alta | Media | Baja |
| **Precisión reportada en literatura** | ~90-95% | ~99% | ~98% | ~99%+ |
| **Adaptabilidad a señal variable** | ✅ Normalización local | Umbral fijo | Media | Alta |
| **Uso en este proyecto** | ✅ **Seleccionado** | Alternativa | Alternativa | Fuera de alcance |

**Justificación de selección:** El enfoque de ventanas con normalización local es más simple de implementar y depurar para un primer prototipo. La normalización por segmento permite adaptarse a variaciones de amplitud entre pacientes.

---

## 4. Comparativa de Métodos de Clasificación de Arritmias

| Criterio | **Umbral BPM por ventana** ✅ | SVM | Random Forest | LSTM/RNN |
|---------|------------------------------|-----|--------------|---------|
| **Complejidad** | Muy baja | Media | Media | Alta |
| **Requiere etiquetas de entrenamiento** | No | Sí | Sí | Sí |
| **Interpretabilidad clínica** | ✅ Alta | Baja | Media | Baja |
| **Clases detectadas** | 3 (Normal, Brady, Tachy) | N clases | N clases | N clases |
| **Generalización** | Baja (reglas fijas) | Alta | Alta | Muy alta |
| **Tiempo de desarrollo** | Bajo | Medio | Medio | Alto |
| **Uso en este proyecto** | ✅ **Seleccionado** | Trabajo futuro | Trabajo futuro | Fuera de alcance |

**Justificación de selección:** Para el alcance del proyecto, la clasificación por umbrales clínicos estandarizados (< 60 bpm / 60-100 bpm / > 100 bpm) es suficiente, transparente y verificable. Los métodos de ML quedan propuestos como trabajo futuro.

---

## 5. Comparativa de Filtros para Preprocesamiento ECG

| Criterio | **Butterworth Pasa-Banda** ✅ | Chebyshev Tipo I | FIR Kaiser | Filtro de media móvil |
|---------|------------------------------|-----------------|-----------|----------------------|
| **Fase** | Cero (con filtfilt) | No lineal | Lineal | No lineal |
| **Orden** | 4 (bajo) | Bajo | Alto | N/A |
| **Ondulación en banda pasante** | Máxima planicidad | Sí | Configurable | — |
| **Atenuación fuera de banda** | Buena | Mejor | Buena | Pobre |
| **Implementación en MATLAB** | ✅ `butter` + `filtfilt` | `cheby1` | `fir1` | `movmean` |
| **Distorsión del QRS** | Mínima con orden 4 | Posible | Mínima con orden alto | Alta |
| **Uso en este proyecto** | ✅ **Seleccionado** | ❌ | ❌ | ❌ |

**Justificación de selección:** El filtro Butterworth maximiza la planicidad en la banda pasante (0.5–40 Hz), preservando la morfología del QRS. El uso de `filtfilt` elimina el desfase de fase, crítico para la localización precisa de picos.

---

## Resumen de Decisiones

| Componente | Alternativa elegida | Razón principal |
|-----------|--------------------|----|
| Dataset | MIT-BIH Arrhythmia DB | Estándar de la industria, acceso libre |
| Herramienta | MATLAB | Signal Processing Toolbox integrado |
| Detección R | Umbral adaptativo por ventana | Sencillez y adaptabilidad |
| Clasificador | Umbral clínico de BPM | Transparencia clínica |
| Filtro | Butterworth Bp 4°, 0.5–40 Hz | Preserva morfología QRS |

---

*Documento elaborado por: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*  
*Fecha: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*
