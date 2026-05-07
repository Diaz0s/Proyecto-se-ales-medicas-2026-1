# 📈 Resultados Preliminares
## Reconocimiento y Clasificación de Arritmias ECG

> **⚠️ PLANTILLA** — Completar con los resultados obtenidos durante el desarrollo.

---

## 1. Contexto

**Fecha de pruebas:** \_\_\_\_\_\_\_\_\_\_\_  
**Registros evaluados:** \_\_\_\_\_\_\_\_\_\_\_  
**Objetivo de esta etapa:** Validar que la lectura de archivos, el filtrado y la detección de picos funcionen correctamente en señales básicas.

---

## 2. Señales Procesadas

| Registro MIT-BIH | Duración evaluada | Ritmo predominante | Observaciones |
|-----------------|------------------|-------------------|---------------|
| *(ej. 100.dat)* | *(ej. 30 min)* | *(ej. Normal)* | *(notas)* |

---

## 3. Resultados de Filtrado

*(Describir el efecto visual del filtro Butterworth sobre la señal. Incluir comparación antes/después.)*

- **Deriva de línea base eliminada:** ✅ / ❌
- **Ruido de alta frecuencia reducido:** ✅ / ❌
- **Morfología QRS preservada:** ✅ / ❌

---

## 4. Resultados de Detección de Picos R

*(Completar con datos reales de una prueba sobre un registro específico.)*

| Métrica | Valor obtenido |
|---------|---------------|
| Total de picos R detectados | — |
| Falsos positivos visibles | — |
| Falsos negativos visibles | — |
| Evaluación cualitativa | — |

---

## 5. Resultados de Clasificación

*(Ejemplo de salida de consola del script. Reemplazar con datos reales.)*

```
Ventana 0.0 - 5.0 s  | BPM: 72.3 | Normal
Ventana 5.0 - 10.0 s | BPM: 68.1 | Normal
Ventana 10.0 - 15.0 s| BPM: 55.2 | Bradicardia
...
```

---

## 6. Figuras

*(Insertar capturas de pantalla de las figuras generadas por MATLAB. Guardarlas en `evidencias/`.)*

| Figura | Descripción |
|--------|-------------|
| `fig_ecg_crudo.png` | Señal ECG sin procesar |
| `fig_ecg_filtrado.png` | Señal después del filtrado |
| `fig_deteccion_picos.png` | Picos R detectados sobre señal filtrada |

---

## 7. Problemas Encontrados

*(Documentar errores, comportamientos inesperados o limitaciones identificadas.)*

- *(Ej. "En el registro 105, se detectan falsos positivos por artefactos de movimiento en los primeros 10s")*

---

## 8. Conclusiones Preliminares

*(Evaluación cualitativa del estado del sistema en esta etapa.)*

---

*Fecha: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*
