# Taller de Optimización de Consultas y Rendimiento en MySQL (BancoDB)

**Estudiante:** Frank David Cuesta Niño
**Motor:** MySQL 8.0.46 (contenedor Docker)
**Cliente:** DBeaver 26.2

## Descripción

Diagnóstico y optimización de consultas lentas sobre la base `BancoDB` mediante `EXPLAIN ANALYZE`, índices compuestos y cubrientes, y reescritura de consultas de forma sargable. El taller parte de la base real del Reto 1, que ya contiene las tablas `cuentas` y `historial_transferencias` junto con el procedimiento `TransferirFondos`. Por lo tanto, en lugar de recrear las tablas, se adaptan con `ALTER TABLE` y se cargan datos masivos para poder medir diferencias reales de rendimiento.

## Cómo ejecutar

1. Antes de empezar, generar un respaldo desde la terminal:

   ```bash
   docker exec <contenedor> mysqldump -u root -p --routines BancoDB > respaldo_bancodb_pre_taller.sql
   ```

2. Abrir `sql/taller1_limpio.sql` en un SQL Editor de DBeaver conectado a MySQL.
3. Ejecutar el script completo con **Alt + X**, sin seleccionar texto. Cada consulta abre su propia pestaña de resultados.
4. Ejecutarlo **una sola vez**. Los `ALTER TABLE` fallan si se repiten, porque las columnas ya existirían, y la carga masiva duplicaría los datos.

> **Nota sobre `EXPLAIN ANALYZE`:** la salida es una sola celda de texto largo. Además, conviene abrir el panel **Valor** o la vista **Texto** para leer el plan completo. Ten en cuenta que `EXPLAIN ANALYZE` sí ejecuta la consulta, a diferencia de `EXPLAIN`, que solo estima el plan.

## Explicación por bloques

**1. Adaptación de la estructura.** Se convierte `id_cuenta` en `AUTO_INCREMENT` y se agregan las columnas `tipo_cuenta`, `estado` y `fecha_apertura` a `cuentas`, junto con `estado_transferencia` y las dos llaves foráneas a `historial_transferencias`. Todas las columnas nuevas llevan `DEFAULT`, de modo que `TransferirFondos` sigue funcionando sin cambios. Además, las llaves foráneas garantizan que una transferencia hacia una cuenta inexistente sea rechazada en lugar de perder el registro.

**2. Carga masiva.** Se insertan 1000 cuentas y 10 000 transferencias dentro de una transacción, lo que reduce el tiempo a segundos en vez de minutos. En consecuencia, la base queda con 1002 cuentas y 10 003 transferencias, contando las filas originales del Reto 1. Después, `ANALYZE TABLE` actualiza las estadísticas que usa el optimizador.

**3. Demostración guiada.** Se compara el plan de una búsqueda por estado y fecha antes y después de crear el índice `idx_transf_estado_fecha`. No obstante, como el estado `'Exitosa'` cubre cerca del 93 % de la tabla, el optimizador sigue prefiriendo el escaneo completo. Por el contrario, con `'Fallida'` (cerca del 7 %) sí aparece el `Index range scan`, lo que demuestra que un índice solo sirve cuando el filtro es selectivo.

**4. Ejercicio 1 (consulta no sargable).** Se muestra en tres pasos por qué `WHERE DATE(fecha) = '2026-02-15'` no usa el índice. Primero, la función `DATE()` sobre la columna impide el uso del índice. Después, aunque se reescriba como un rango sargable, el índice compuesto no aplica porque empieza por `estado_transferencia`. En consecuencia, se crea `idx_transf_fecha` y la consulta pasa a un `Index range scan`.

**5. Ejercicio 2 (índice cubriente).** Se diseña un índice sobre `cuentas` que contiene la columna del `WHERE` y los campos retornados, de modo que la consulta se resuelve solo con el índice ("Using index" en `EXPLAIN`, o "Covering index lookup" en `EXPLAIN ANALYZE`). Sin embargo, al usar `SELECT *`, MySQL vuelve al escaneo completo, porque el índice no contiene todas las columnas.

**6. Ejercicio 3 (JOIN y filtros combinados).** Se agrega el filtro de "últimos 30 días" y se crea el índice compuesto `(fecha, monto, cuenta_origen)` sobre `historial_transferencias`. Por lo tanto, la consulta pasa a un `Covering index range scan`, sin ningún `Table scan`, y `cuentas` se resuelve por su llave primaria.

## Respuestas a las preguntas teóricas

**Ejercicio 1: ¿por qué no se usa el índice?**
El índice almacena los valores de `fecha` ordenados, pero no los de `DATE(fecha)`. Por lo tanto, MySQL debe evaluar la función fila por fila, y la condición deja de ser sargable. Además, aunque se reescriba como un rango, el índice `idx_transf_estado_fecha` empieza por `estado_transferencia`. Según la regla del prefijo izquierdo, un índice compuesto solo se aprovecha cuando la consulta filtra por sus primeras columnas (Oracle, s.f.-b).

**Ejercicio 2: `SELECT *` frente a campos específicos.**
`SELECT *` obliga a leer columnas que no están en el índice, de modo que MySQL debe volver a la tabla base por cada fila o prefiere escanearla completa. Por el contrario, cuando todas las columnas solicitadas están en el índice, la consulta se responde solo con él, lo que se refleja en "Using index" (Oracle, s.f.-a).

**Ejercicio 3: orden de columnas en el índice.**
La tabla que conduce el JOIN es `historial_transferencias`, porque sus filtros son los que más reducen las filas. En consecuencia, `fecha` va primero por ser el rango más selectivo, `monto` va después y se evalúa dentro del índice mediante *index condition pushdown*, y `cuenta_origen` completa la cobertura y entrega la llave del JOIN. No se indexó `cuentas.estado`, porque cerca del 90 % de las cuentas están activas y ese filtro no es selectivo (Oracle, s.f.-c).

## Resultados esperados

- Tras el Bloque de estructura, `cuentas` muestra `id_cuenta` con `auto_increment` y las tres columnas nuevas; `historial_transferencias` incluye `estado_transferencia` y las dos llaves foráneas.
- La carga masiva deja 1002 cuentas y 10 003 transferencias (Exitosa ≈ 9337, Fallida = 666).
- En la demostración, `'Exitosa'` conserva el `Table scan` y `'Fallida'` pasa a `Index range scan`.
- En el Ejercicio 2, `EXPLAIN` muestra "Using index" con el índice cubriente, mientras que `SELECT *` vuelve a `type = ALL`.
- En el Ejercicio 3, el plan final es un `Covering index range scan` sin ningún `Table scan`.
- `TransferirFondos(1, 2, 100, @codigo, @titular)` devuelve el código 200 y el titular `Ana López`, lo que confirma que el Reto 1 sigue operativo.

## Checklist de requisitos

- [x] Adaptación de la estructura con `ALTER TABLE` (sin `DROP TABLE`)
- [x] `id_cuenta` como `AUTO_INCREMENT` y columnas nuevas con `DEFAULT`
- [x] Carga masiva de 1000 cuentas y 10 000 transferencias dentro de una transacción
- [x] Ejercicio 1: diagnóstico de consulta no sargable y reescritura por rango
- [x] Ejercicio 2: índice cubriente con resultado de "Using index" / "Covering index"
- [x] Ejercicio 3: índice compuesto para el JOIN con filtro de fecha
- [x] Comparación de planes ANTES y DESPUÉS de cada índice
- [x] Respuestas a las tres preguntas teóricas
- [x] Verificación de que `TransferirFondos` sigue operativo

## Referencias

Oracle. (s.f.-a). *EXPLAIN statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/explain.html

Oracle. (s.f.-b). *Multiple-column indexes*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html

Oracle. (s.f.-c). *Range optimization*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/range-optimization.html
