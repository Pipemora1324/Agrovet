# Figuras del clasificador de leche

Generadas por `ml/src/train_milk_cnn.py`. Los números de cada figura están en
`ml/reports/milk_cnn.json` y se explican en `docs/gestion/pruebas/calidad_datos.md` (sección 4).

| Archivo | Qué muestra |
|---|---|
| `calibracion.png` | Curva de calibración de las dos arquitecturas con todas las predicciones fuera de muestra (5 repeticiones) |
| `gradcam_<arquitectura>_<categoría>.png` | Grad-CAM de aciertos y errores de la repetición 0: arriba el recorte del pozo, abajo dónde miró la red. Cada pozo lo explica el modelo del fold que **no** lo vio en el entrenamiento. En los errores se muestran los más seguros (los más graves); en los aciertos, unos al azar |

## Atribución

Las imágenes de los pozos son recortes de:

> abdurrehman4198. *Mastitis dataset* (versión 3). Roboflow Universe, 2026.
> https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset
> Licencia [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Cambios hechos: recorte de cada pozo (caja más 10 %), relleno a cuadrado, redimensionado a 160 px y
superposición del mapa Grad-CAM. Las etiquetas son del autor del dataset.
