# 📁 Instrucciones para obtener el Dataset

El dataset **MIT-BIH Arrhythmia Database** no está incluido en este repositorio por su tamaño (~100 MB). Sigue las instrucciones a continuación para descargarlo.

---

## Opción 1 — Descarga manual desde PhysioNet (recomendado)

1. Ir a: https://physionet.org/content/mitdb/1.0.0/
2. Crear una cuenta gratuita en PhysioNet (si no tienes una)
3. Aceptar los términos de uso (licencia ODC-By)
4. Descargar los archivos `.dat`, `.hea` y `.atr` de los registros que necesites
5. Colocarlos en esta carpeta: `data/mitdb/`

---

## Opción 2 — Descarga con wget (Linux / macOS / WSL)

```bash
mkdir -p data/mitdb
wget -r -N -c -np https://physionet.org/files/mitdb/1.0.0/ -P data/mitdb/
```

---

## Opción 3 — Descarga con Python (wfdb)

```bash
pip install wfdb
```

```python
import wfdb
# Descargar registros específicos
wfdb.dl_files('mitdb', 'data/mitdb', ['100.dat', '100.hea', '100.atr'])

# O todos los registros
wfdb.dl_database('mitdb', 'data/mitdb')
```

---

## Registros sugeridos para pruebas

| Registro | Características |
|---------|----------------|
| `100` | Ritmo sinusal normal (buena señal para pruebas iniciales) |
| `101` | Normal con algunas PVC aisladas |
| `108` | Múltiples arritmias, señal más ruidosa |
| `207` | Fibrilación auricular y taquicardia ventricular |
| `217` | Bradicardia marcada |

---

## Estructura de archivos esperada

```
data/
└── mitdb/
    ├── 100.dat
    ├── 100.hea
    ├── 100.atr
    ├── 101.dat
    ├── 101.hea
    ...
```

---

## Cita requerida

Si usas este dataset en publicaciones o informes académicos:

> Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database. *IEEE Eng in Med and Biol* 20(3):45-50 (2001).

> Goldberger AL, et al. PhysioBank, PhysioToolkit, and PhysioNet. *Circulation* 101(23):e215-e220 (2000).
