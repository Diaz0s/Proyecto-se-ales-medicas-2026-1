# 📄 Reporte de Fundamentación Teórica
## Reconocimiento y Clasificación de Arritmias ECG

> **⚠️ PLANTILLA** — Completar con el desarrollo teórico del equipo.

---

## 1. Introducción

*(Describir el contexto clínico del problema: relevancia de las enfermedades cardiovasculares, necesidad de monitoreo continuo, limitaciones del diagnóstico manual.)*

---

## 2. El Electrocardiograma (ECG)

### 2.1 Fisiología del corazón
*(Explicar el sistema de conducción eléctrica: nodo SA, nodo AV, haz de His, fibras de Purkinje.)*

### 2.2 Morfología de la señal ECG
*(Describir las ondas P, Q, R, S, T y el segmento ST. Incluir figura de referencia.)*

| Componente | Duración típica | Amplitud típica | Significado fisiológico |
|-----------|----------------|----------------|------------------------|
| Onda P | 80–120 ms | 0.1–0.3 mV | Despolarización auricular |
| Complejo QRS | 60–100 ms | 0.5–3.0 mV | Despolarización ventricular |
| Intervalo RR | 600–1000 ms | — | Ciclo cardíaco completo |
| Onda T | 160 ms | 0.1–0.5 mV | Repolarización ventricular |

### 2.3 Frecuencia cardíaca normal
*(Definir rangos: Normal 60–100 bpm, Bradicardia < 60 bpm, Taquicardia > 100 bpm.)*

---

## 3. Arritmias Cardíacas

### 3.1 Definición y clasificación
*(Definir arritmia y presentar la clasificación principal: supraventriculares, ventriculares, de conducción.)*

### 3.2 Arritmias de interés en este proyecto

#### 3.2.1 Bradicardia sinusal
*(Descripción, causas, manifestación en ECG.)*

#### 3.2.2 Taquicardia sinusal
*(Descripción, causas, manifestación en ECG.)*

#### 3.2.3 Fibrilación auricular
*(Descripción, causas, manifestación en ECG — si aplica al alcance del proyecto.)*

---

## 4. Adquisición y Formato de la Señal

### 4.1 Sistema de derivaciones
*(Explicar derivaciones de extremidades y precordiales. Indicar cuál usa MIT-BIH: MLII y V5.)*

### 4.2 Formato WFDB
*(Describir el formato Waveform Database, archivos .dat, .hea, .atr y su estructura.)*

### 4.3 Formato 212
*(Explicar la codificación de 12 bits en grupos de 3 bytes usada en MIT-BIH.)*

---

## 5. Procesamiento Digital de Señales ECG

### 5.1 Fuentes de ruido en ECG
| Tipo de ruido | Rango de frecuencia | Causa |
|--------------|-------------------|-------|
| Interferencia de red eléctrica | 50/60 Hz | Red eléctrica |
| Movimiento de electrodos | 0–10 Hz | Movimiento del paciente |
| Derivas de la línea base | < 0.5 Hz | Respiración, sudoración |
| Electromiografía (EMG) | > 100 Hz | Actividad muscular |

### 5.2 Filtrado
*(Justificar el uso del filtro Butterworth pasa-banda 0.5–40 Hz: elimina deriva de línea base y ruido de alta frecuencia sin distorsionar el complejo QRS.)*

### 5.3 Detección de picos R — Estado del arte
*(Describir algoritmos clásicos: Pan-Tompkins (1985), derivada + umbral adaptativo, comparar con el enfoque implementado.)*

---

## 6. Clasificación del Ritmo Cardíaco

### 6.1 Análisis de intervalos RR
*(Explicar cómo los intervalos entre picos R determinan la frecuencia cardíaca y permiten clasificar el ritmo.)*

### 6.2 Enfoque por ventanas
*(Justificar el uso de ventanas temporales de 5 segundos para el cálculo del BPM promedio.)*

---

## 7. Justificación del Enfoque Adoptado

*(Argumentar por qué se eligió MATLAB, por qué MIT-BIH y por qué el algoritmo de detección implementado frente a las alternativas.)*

---

## 8. Referencias

*(Insertar referencias en formato IEEE.)*

1. Pan J, Tompkins WJ. A real-time QRS detection algorithm. *IEEE Trans Biomed Eng.* 1985;32(3):230-236.
2. Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database. *IEEE Eng in Med and Biol.* 2001;20(3):45-50.
3. Goldberger AL, et al. PhysioBank, PhysioToolkit, and PhysioNet. *Circulation.* 2000;101(23):e215-e220.
4. *(Agregar referencias adicionales)*

---

*Documento elaborado por: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*  
*Fecha: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*
