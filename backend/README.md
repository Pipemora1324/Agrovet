# backend — API de AgroVet

API REST en Java 21 y Spring Boot 3 con PostgreSQL 15. Gestiona usuarios, bovinos,
registros diarios, inferencias y alertas, y recibe la sincronización por lotes desde la app.

La conexión a la base y los secretos se leen de variables de entorno; `.env.example` trae
los valores de ejemplo del docker-compose local. El mismo código sirve después con el
PostgreSQL de un servidor propio cambiando solo esas variables.

Las instrucciones de ejecución y pruebas se agregan junto con el código.
