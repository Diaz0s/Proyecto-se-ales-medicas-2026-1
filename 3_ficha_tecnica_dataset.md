# 🗂️ Ficha Técnica del Dataset
## MIT-BIH Arrhythmia Database

---

## 1. Identificación General

| Campo | Descripción |
|-------|-------------|
| **Nombre oficial** | MIT-BIH Arrhythmia Database |
| **Versión** | 1.0.0 |
| **Fuente** | PhysioNet — MIT Laboratory for Computational Physiology |
| **URL** | https://physionet.org/content/mitdb/1.0.0/ |
| **DOI** | https://doi.org/10.13026/C2F305 |
| **Año de publicación** | 1980 (primera versión) / 2005 (PhysioNet) |
| **Licencia** | Open Data Commons Attribution License v1.0 (ODC-By) |
| **Acceso** | Público y gratuito |

---

## 2. Descripción General

La MIT-BIH Arrhythmia Database es el estándar de referencia mundial para el desarrollo y evaluación de algoritmos de detección de arritmias. Fue creada en el MIT Beth Israel Hospital y contiene registros de ECG ambulatorio de dos canales con anotaciones verificadas por cardiólogos expertos.

Es ampliamente utilizada en investigaciones de aprendizaje automático, procesamiento de señales biomédicas y sistemas de monitoreo cardíaco.

---

## 3. Características Técnicas de la Señal

| Parámetro | Valor |
|-----------|-------|
| **Número de registros** | 48 |
| **Duración por registro** | ~30 minutos |
| **Frecuencia de muestreo** | 360 Hz |
| **Resolución** | 11 bits sobre un rango de ±5 mV |
| **Número de canales** | 2 (derivaciones de ECG) |
| **Ganancia típica** | 200 ADC unidades/mV |
| **Formato de archivo** | WFDB (Waveform Database) |
| **Extensiones** | `.dat` (señal binaria), `.hea` (cabecera), `.atr` (anotaciones) |
| **Formato binario** | Formato 212 (12 bits comprimidos en grupos de 3 bytes) |

---

## 4. Estructura de Archivos WFDB

### 4.1 Archivo `.hea` (Header)
Contiene metadatos del registro en texto plano:
```
100 2 360 650000          ← [nombre] [canales] [Fs] [num_muestras]
100.dat 212 200 11 1024 995 -22131 0 MLII
100.dat 212 200 11 1024 1011 20052 0 V5
```

### 4.2 Archivo `.dat` (Datos binarios)
- Señal en formato 212: cada 3 bytes almacenan 2 muestras de 12 bits
- Requiere decodificación específica para recuperar los valores de amplitud

### 4.3 Archivo `.atr` (Anotaciones)
- Contiene las marcas temporales y tipos de latidos anotados por cardiólogos
- Más de 109 tipos de anotaciones distintas (Normal, PVC, APC, etc.)

---

## 5. Distribución de Registros

| Rango de IDs | Descripción |
|-------------|-------------|
| 100–109 | Registros con ritmo sinusal normal predominante |
| 200–234 | Registros con mayor variedad de arritmias complejas |
| 102, 104 | Contienen marcapasos |

### Arritmias presentes en la base de datos

| Tipo de Arritmia | Símbolo | Descripción |
|-----------------|---------|-------------|
| Normal | N | Latido sinusal normal |
| Bloqueo de rama izquierda | L | LBBB |
| Bloqueo de rama derecha | R | RBBB |
| Contracción ventricular prematura | V | PVC |
| Contracción auricular prematura | A | APC |
| Nodo AV nodal | J | Junctional beat |
| Flutter auricular | AFL | Ritmo rápido auricular |
| Fibrilación auricular | AFIB | Ritmo irregular |
| Taquicardia ventricular | VT | Ritmo ventricular rápido |

---

## 6. Relevancia para este Proyecto

| Aspecto | Uso en el proyecto |
|---------|-------------------|
| **Señal de entrada** | Archivos `.dat` + `.hea` leídos en MATLAB |
| **Frecuencia de muestreo** | 360 Hz → define parámetros de filtrado y detección |
| **Formato 212** | Implementado en el script de decodificación MATLAB |
| **Ganancia** | Aplicada para convertir ADC a milivoltios |
| **Duración** | 30 min → permite clasificación en múltiples ventanas de 5s |
| **Anotaciones** | Pueden usarse como ground truth para validación |

---

## 7. Estadísticas del Dataset

| Métrica | Valor |
|---------|-------|
| Tamaño total aprox. | ~100 MB |
| Total de latidos anotados | ~110,000 |
| Número de tipos de latidos | 15+ categorías principales |
| Sujetos | 47 pacientes (25 hombres, 22 mujeres) |
| Rango de edad | 23–89 años |
| Proporción Normal/Anormal | ~60% normal, ~40% anormal |

---

## 8. Consideraciones Éticas y de Uso

- Los datos han sido **anonimizados** y no contienen información identificable de los pacientes.
- El uso es permitido para **investigación académica y científica** bajo licencia ODC-By.
- Se debe citar la fuente original en publicaciones:

> Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database. *IEEE Eng in Med and Biol* 20(3):45-50 (May-June 2001). (PMID: 11446209)

> Goldberger, A., Amaral, L., Glass, L., et al. PhysioBank, PhysioToolkit, and PhysioNet: Components of a New Research Resource for Complex Physiologic Signals. *Circulation* 101(23):e215–e220 (2000).

---

## 9. Instrucciones de Descarga

```bash
# Opción 1: Descarga directa desde PhysioNet
# Visitar: https://physionet.org/content/mitdb/1.0.0/

# Opción 2: Usando wget (Linux/Mac)
wget -r -N -c -np https://physionet.org/files/mitdb/1.0.0/

# Opción 3: Usando el paquete WFDB para Python
pip install wfdb
python -c "import wfdb; wfdb.dl_database('mitdb', './data/mitdb')"
```

Colocar los archivos descargados en la carpeta `data/mitdb/` del repositorio.

---

*Última actualización: 2025*
