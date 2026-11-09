# Datasets públicos usados o revisados

Ningún dataset público se guarda en este repositorio. Se descargan aparte y los scripts reciben la
ruta como argumento. En el repo solo quedan métricas agregadas y el modelo exportado.

## Ubres — usado para la CNN de triaje visual

| Campo | Valor |
|---|---|
| Nombre | Mastitis, versión 1 |
| Fuente | Roboflow Universe, espacio `yield-a2yrd`, proyecto `mastitis-zmser` — <https://universe.roboflow.com/yield-a2yrd/mastitis-zmser> |
| Autor | Usuario de Roboflow (el proyecto no declara un autor con nombre) |
| Licencia | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Contenido | 124 fotos de ubres, 432 × 432 (Roboflow las estiró a ese tamaño), un polígono por ubre, clases Mastitis-No / Low / Moderate / High |
| Exportación usada | COCO Segmentation, exportada el 2026-06-16 |

Cambios aplicados (CC BY 4.0 pide indicarlos):

- Etiqueta binaria: sana = Mastitis-No; con signos de mastitis = Low + Moderate + High.
- Recorte de la ubre: caja del polígono más grande + 10 % de margen por lado, relleno negro hasta un
  cuadrado y reescalado a 224 × 224. Se descartan 7 fotos cuyo recorte tiene el lado corto < 96 px.
- Agrupación por vaca o escena (hash perceptual y revisión manual) para la validación cruzada.

Las etiquetas son del autor del dataset, **sin confirmación veterinaria**. Las métricas miden la
concordancia con esas etiquetas, no una capacidad diagnóstica. Resultados y limitaciones en
[ml/README.md](../ml/README.md#cnn-de-triaje-visual-de-la-ubre).

Cita sugerida: *Mastitis (v1) [Conjunto de datos]. Roboflow Universe, yield-a2yrd.
https://universe.roboflow.com/yield-a2yrd/mastitis-zmser. Licencia CC BY 4.0.*

## Leche en paleta — prueba de concepto, no se usa en la app

| Campo | Valor |
|---|---|
| Nombre | Mastitis dataset, versión 3 (2026-09-03) |
| Fuente | Roboflow Universe — <https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset> |
| Autor | Usuario de Roboflow (sin autor declarado) |
| Licencia | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Contenido | 453 imágenes (frames de video y fotos de teléfono) de una paleta de 4 pocillos, 640 cajas: Normal, Watery, Curd like y Blood tinged Milk |

## Series IoT — revisado y descartado

| Campo | Valor |
|---|---|
| Nombre | Data for: Clinical Mastitis in Cows based on Udder Parameter using Internet of Things (IoT) |
| Fuente | Mendeley Data, DOI [10.17632/kbvcdw5b4m.2](https://data.mendeley.com/datasets/kbvcdw5b4m/2) |
| Autores | Ankitha K, Manjaiah D H, Kartik M (2020) |
| Licencia | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

No se usa para el modelo LSTM: no tiene producción de leche ni consumo de alimento, cada vaca tiene
solo 6 días (el modelo usa ventanas de 14), la etiqueta es idéntica a la variable de leche anormal y
la temperatura está fuera del rango fisiológico. Se cita solo en el estado del arte.
