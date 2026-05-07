# REPORTE DE FUNDAMENTACIÓN TEÓRICA

## Reconocimiento y Clasificación de Arritmias ECG

---

# 1. Introducción

Las enfermedades cardiovasculares representan la principal causa de muerte a nivel mundial, siendo responsables de aproximadamente 17,9 millones de defunciones anuales según la Organización Mundial de la Salud, lo que equivale al 32% de todas las muertes globales. Dentro de este espectro, las arritmias cardíacas constituyen una de las patologías más frecuentes y potencialmente letales, caracterizadas por alteraciones en el ritmo normal del corazón que pueden comprometer gravemente la función cardíaca.

El electrocardiograma (ECG) es la herramienta diagnóstica estándar para la detección de arritmias. Registra la actividad eléctrica del corazón a lo largo del tiempo y proporciona información crítica sobre el ritmo, la frecuencia, la conducción y la morfología de los latidos. Sin embargo, el análisis manual de registros ECG prolongados, como los estudios Holter de 24 horas, representa una carga cognitiva significativa para el personal médico y es susceptible a errores por fatiga o variabilidad inter-observador.

Ante este panorama, el procesamiento automático de señales ECG mediante algoritmos computacionales emerge como una solución de alto impacto clínico. Los sistemas de detección y clasificación automática de arritmias permiten analizar horas de registro en segundos, con criterios objetivos y reproducibles, facilitando el diagnóstico oportuno y el monitoreo continuo de pacientes en riesgo.

El presente proyecto desarrolla un sistema en MATLAB para el reconocimiento y clasificación de arritmias cardíacas a partir de señales ECG de la base de datos MIT-BIH Arrhythmia Database, implementando técnicas de procesamiento digital de señales y aprendizaje automático con clasificadores Random Forest.

---

# 2. El Electrocardiograma (ECG)

## 2.1 Fisiología del corazón

El corazón es un órgano muscular cuya función de bomba está regulada por un sistema de conducción eléctrica intrínseco y altamente organizado. Este sistema genera y propaga impulsos eléctricos que despolarizan el músculo cardíaco de manera coordinada, produciendo las contracciones rítmicas necesarias para la circulación sanguínea.

El sistema de conducción cardíaca está compuesto por los siguientes nodos y vías especializadas:

* **Nodo sinoauricular (SA):** Ubicado en la pared de la aurícula derecha, actúa como el marcapasos natural del corazón, generando impulsos eléctricos a una frecuencia de 60 a 100 impulsos por minuto en condiciones de reposo.

* **Nodo auriculoventricular (AV):** Situado en la unión entre aurículas y ventrículos, introduce un retardo fisiológico de aproximadamente 120 a 200 ms.

* **Haz de His:** Conjunto de fibras de conducción rápida que atraviesa el tabique interventricular y conecta el nodo AV con los ventrículos.

* **Fibras de Purkinje:** Red de fibras responsables de distribuir el impulso eléctrico de manera uniforme por todo el miocardio ventricular.

Cuando alguno de estos componentes falla o presenta alteraciones, se producen las arritmias cardíacas.

---

## 2.2 Morfología de la señal ECG

La señal ECG refleja la actividad eléctrica agregada de millones de células miocárdicas captada desde la superficie corporal. Cada ciclo cardíaco produce un patrón morfológico característico compuesto por ondas, intervalos y segmentos.

| Componente   | Duración típica | Amplitud típica | Significado fisiológico                |
| ------------ | --------------- | --------------- | -------------------------------------- |
| Onda P       | 80 – 120 ms     | 0.1 – 0.3 mV    | Despolarización auricular              |
| Intervalo PR | 120 – 200 ms    | —               | Conducción por nodo AV                 |
| Complejo QRS | 60 – 100 ms     | 0.5 – 3.0 mV    | Despolarización ventricular            |
| Onda Q       | < 40 ms         | < 0.1 mV        | Despolarización inicial septal         |
| Onda R       | Pico principal  | 0.5 – 3.0 mV    | Pico principal ventricular             |
| Onda S       | Variable        | Variable        | Despolarización de bases ventriculares |
| Segmento ST  | Variable        | Isoeléctrico    | Inicio repolarización ventricular      |
| Onda T       | 160 ms          | 0.1 – 0.5 mV    | Repolarización ventricular             |
| Intervalo RR | 600 – 1000 ms   | —               | Ciclo cardíaco completo                |
| Intervalo QT | 350 – 440 ms    | —               | Sístole ventricular eléctrica          |

El complejo QRS es el componente de mayor relevancia clínica y técnica en este proyecto.

---

## 2.3 Frecuencia cardíaca y rangos clínicos

La frecuencia cardíaca se calcula a partir de los intervalos RR consecutivos.

FC=\frac{60}{RR,(s)}

| Condición            | Rango de FC  | Características              |
| -------------------- | ------------ | ---------------------------- |
| Bradicardia          | < 60 bpm     | Frecuencia anormalmente baja |
| Ritmo sinusal normal | 60 – 100 bpm | Frecuencia fisiológica       |
| Taquicardia          | > 100 bpm    | Frecuencia anormalmente alta |

---

# 3. Arritmias Cardíacas

## 3.1 Definición y clasificación

Una arritmia cardíaca es cualquier alteración en el ritmo, frecuencia, origen o conducción del impulso eléctrico cardíaco.

Las principales categorías son:

* **Arritmias supraventriculares**
* **Arritmias ventriculares**
* **Trastornos de la conducción**

---

## 3.2 Arritmias clasificadas en este proyecto

### 3.2.1 Latido Normal (N)

Se origina en el nodo SA y sigue la secuencia fisiológica normal de conducción.

### 3.2.2 Bloqueo de Rama Izquierda — LBBB (L)

Se produce por alteración en la conducción de la rama izquierda del Haz de His.

### 3.2.3 Bloqueo de Rama Derecha — RBBB (R)

Afecta la rama derecha del sistema de conducción ventricular.

### 3.2.4 Contracción Auricular Prematura — APC (A)

Latidos ectópicos originados en las aurículas.

### 3.2.5 Contracción Ventricular Prematura — PVC (V)

Latidos originados en focos ectópicos ventriculares con QRS ancho y morfología aberrante.

---

# 4. Adquisición y Formato de la Señal

## 4.1 Sistema de derivaciones ECG

La base de datos MIT-BIH utiliza principalmente dos derivaciones:

* **MLII (Modified Lead II)**
* **V5**

Este proyecto trabaja principalmente con el canal MLII.

---

## 4.2 Formato WFDB (Waveform Database)

Cada registro contiene tres archivos:

| Extensión | Tipo         | Contenido                |
| --------- | ------------ | ------------------------ |
| .hea      | Texto plano  | Información del registro |
| .dat      | Binario      | Señal ECG digitalizada   |
| .atr      | Binario WFDB | Anotaciones clínicas     |

---

## 4.3 Formato de codificación 212

El formato 212 almacena muestras de 12 bits en grupos de 3 bytes.

Proceso:

* Cada grupo contiene dos muestras.
* Se combinan bits de distintos bytes.
* Se utiliza complemento a dos para valores negativos.

---

# 5. Procesamiento Digital de Señales ECG

## 5.1 Fuentes de ruido en registros ECG

| Tipo de ruido            | Rango de frecuencia | Causa principal         | Efecto                       |
| ------------------------ | ------------------- | ----------------------- | ---------------------------- |
| Deriva de línea base     | < 0.5 Hz            | Respiración             | Desplazamiento de línea base |
| Artefactos de movimiento | 0.1 – 10 Hz         | Movimiento del paciente | Distorsiones bruscas         |
| Interferencia eléctrica  | 50/60 Hz            | Red eléctrica           | Oscilación sinusoidal        |
| Ruido EMG                | > 100 Hz            | Actividad muscular      | Enmascara detalles           |

---

## 5.2 Filtrado Butterworth pasa-banda

Se emplea un filtro Butterworth de orden 4 con banda pasante de 0.5 a 40 Hz.

Las razones principales son:

* Eliminar deriva de línea base.
* Reducir ruido muscular.
* Atenuar interferencia eléctrica.
* Preservar la morfología del QRS.

---

## 5.3 Detección de picos R

### 5.3.1 Algoritmo Pan-Tompkins

El algoritmo Pan-Tompkins es un método clásico para detección de complejos QRS.

Etapas:

1. Filtrado
2. Derivación
3. Elevación al cuadrado
4. Integración móvil
5. Umbral adaptativo

---

### 5.3.2 Enfoque implementado

El sistema implementa detección mediante:

* Ventanas deslizantes
* Normalización local
* Umbral adaptativo del 50%

---

# 6. Clasificación del Ritmo Cardíaco

## 6.1 Análisis de intervalos RR

El intervalo RR es la distancia entre dos picos R consecutivos.

Patrones relevantes:

* RR largos y luego cortos → PVC
* RR irregulares → Fibrilación auricular
* RR cortos constantes → Taquicardia
* RR largos constantes → Bradicardia

---

## 6.2 Extracción de features

Se extraen 23 características por latido.

| Categoría     | Features principales        |
| ------------- | --------------------------- |
| Morfológicas  | Amplitud, energía, curtosis |
| RR            | RR previo y posterior       |
| Espectrales   | Potencia en bandas          |
| Forma de onda | Pendientes y áreas          |

---

## 6.3 Random Forest

El clasificador Random Forest fue seleccionado por:

* Robustez al ruido
* Manejo de clases desbalanceadas
* Interpretabilidad
* Buen desempeño general

Configuración utilizada:

* 100 árboles
* 5 muestras mínimas por hoja
* Aproximadamente 5 features por división

---

# 7. Justificación del Enfoque Adoptado

| Componente   | Elección          | Justificación               |
| ------------ | ----------------- | --------------------------- |
| Herramienta  | MATLAB            | Entorno robusto para DSP    |
| Dataset      | MIT-BIH           | Base estándar internacional |
| Filtro       | Butterworth       | Preserva morfología         |
| Detección R  | Umbral adaptativo | Simple y robusto            |
| Clasificador | Random Forest     | Alta precisión              |

---

# 8. Referencias

1. Pan J, Tompkins WJ. *A real-time QRS detection algorithm*. IEEE Transactions on Biomedical Engineering. 1985.

2. Moody GB, Mark RG. *The impact of the MIT-BIH Arrhythmia Database*. IEEE Engineering in Medicine and Biology Magazine. 2001.

3. Goldberger AL et al. *PhysioBank, PhysioToolkit, and PhysioNet*. Circulation. 2000.

4. Breiman L. *Random Forests*. Machine Learning. 2001.

5. Sörnmo L, Laguna P. *Bioelectrical Signal Processing in Cardiac and Neurological Applications*. Academic Press. 2005.

6. Proakis JG, Manolakis DG. *Digital Signal Processing*. Pearson. 2006.

7. [World Health Organization](https://www.who.int?utm_source=chatgpt.com) – Cardiovascular diseases fact sheet.

