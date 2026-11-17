# Fotos de prueba del clasificador de leche

Cinco fotos del **Mastitis dataset v3** de Roboflow Universe (usuario abdurrehman4198),
<https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset>, licencia
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Se copian sin cambios; solo se renombran
(`case_N.jpg`). El nombre original de cada una está en `ml/models/milk_cnn_vectors.json`.

`case_N_crop160.png` es el recorte de 160 px que produce `ml/` (`udder_crop`) para el pozo de ese caso.

Sirven para comprobar que la app prepara la foto igual que Python (`mobile/test/model/milk_model_test.dart`
y `ml/tests/test_milk_vectors.py`). Estos pozos estuvieron en el entrenamiento del modelo final, así
que no dicen nada sobre su exactitud. Las regenera `python src/export_milk_vectors.py --coco <carpeta>`.
