# 🖼️ Evidencias de Implementación

Esta carpeta contiene las capturas de pantalla y figuras generadas durante la implementación del proyecto.

## Figuras esperadas

| Archivo | Descripción | Estado |
|---------|-------------|--------|
| `fig_ecg_crudo.png` | ECG original sin procesar (primeros 30 min o fracción) | ⬜ Pendiente |
| `fig_ecg_filtrado.png` | ECG después del filtro Butterworth 0.5–40 Hz | ⬜ Pendiente |
| `fig_deteccion_picos.png` | ECG filtrado con picos R marcados en rojo | ⬜ Pendiente |
| `fig_qrs_ejemplo.png` | Zoom sobre un complejo QRS con Q, R, S marcados | ⬜ Pendiente |
| `fig_clasificacion_consola.png` | Captura de pantalla de la salida de consola | ⬜ Pendiente |

## Cómo guardar figuras en MATLAB

```matlab
% Guardar figura actual como PNG
saveas(gcf, '../evidencias/fig_ecg_crudo.png')

% O con mayor resolución
print('../evidencias/fig_ecg_filtrado', '-dpng', '-r300')
```

## Instrucciones

1. Ejecutar el script `src/ecg_clasificador.m` sobre al menos un registro de MIT-BIH.
2. Guardar cada figura generada con los nombres indicados arriba.
3. Colocarlas en esta carpeta (`evidencias/`).
4. Actualizar la columna "Estado" en esta tabla.
