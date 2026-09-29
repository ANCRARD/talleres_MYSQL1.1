# Taller de Funciones Definidas por el Usuario en MySQL (Sistema Bancario)

**Estudiante:** Frank David Cuesta Niño
**Motor:** MySQL 8.0.46 (contenedor Docker)
**Cliente:** DBeaver 26.2

## Descripción

Creación de cuatro funciones definidas por el usuario sobre un esquema bancario, que abarcan desde un cálculo matemático puro hasta la evaluación de reglas de negocio con lectura de datos. El taller distingue las funciones `DETERMINISTIC`, que dependen solo de sus parámetros, de las funciones `READS SQL DATA`, que consultan tablas. Además, incluye el uso de estructuras de control como `IF` y el bucle `WHILE`.

## Esquema que asume el taller

Este taller está diseñado para una base con las siguientes tablas, distinta de la base `BancoDB` del Reto 1:

- `Cuentas (cuenta_id, titular, saldo)`
- `Transacciones (cuenta_id, tipo_transaccion, monto, fecha)`, donde `tipo_transaccion` admite valores como `'Retiro'`.

Por lo tanto, las funciones que leen datos requieren que esas tablas existan con esos nombres y columnas. Si se ejecuta sobre un esquema diferente, las funciones `DETERMINISTIC` funcionan igual, pero las que consultan `Transacciones` fallarían con el error 1146.

## Cómo ejecutar

1. Abrir `sql/taller_funciones_limpio.sql` en un SQL Editor de DBeaver conectado a la base bancaria correspondiente.
2. Ejecutar el script completo con **Alt + X**. Cada bloque `CREATE FUNCTION` usa `DELIMITER //`, de modo que debe ejecutarse tal cual.
3. Las últimas consultas del script prueban cada función y abren su propia pestaña de resultados.

## Explicación por bloques

**1. `CalcularImpuestoGMF` (DETERMINISTIC).** Calcula el impuesto del 4x1000, equivalente al 0,4 % del monto. Recibe un indicador booleano de exención, de modo que devuelve cero cuando la operación está exenta. Es `DETERMINISTIC` porque no consulta ninguna tabla, sino que opera solo con sus parámetros.

**2. `ObtenerTotalRetirosPeriodo` (READS SQL DATA).** Suma los montos de las transacciones de tipo `'Retiro'` de una cuenta dentro de un rango de fechas. Además, usa `IFNULL` para devolver cero cuando no hay retiros, en lugar de `NULL`. Es `READS SQL DATA` porque consulta la tabla `Transacciones`.

**3. `ProyectarRendimientoCDT` (DETERMINISTIC).** Proyecta el capital de un CDT con interés compuesto mediante un bucle `WHILE`, que aplica la tasa anual una vez por cada año. Por lo tanto, ilustra el uso de una estructura iterativa dentro de una función.

**4. `EvaluarElegibilidadCredito` (READS SQL DATA).** Evalúa la elegibilidad crediticia de una cuenta combinando su saldo con el total histórico de retiros. Primero verifica que la cuenta exista, de modo que devuelve `'Cuenta Inexistente'` si el saldo es `NULL`. Después aplica reglas de negocio escalonadas con `IF` y `ELSEIF` para clasificar la cuenta como `'Aprobado'`, `'Requiere Aval'` o `'Rechazado'`.

## Resultados esperados

Las funciones `DETERMINISTIC` producen resultados fijos, verificables sin datos:

- `CalcularImpuestoGMF(1000000.00, FALSE)` devuelve **4000.00**, es decir, el 0,4 % del monto.
- `CalcularImpuestoGMF(1000000.00, TRUE)` devuelve **0.00**, porque la operación está exenta.
- `ProyectarRendimientoCDT(10000000.00, 10.50, 3)` devuelve **13492326.25**, tras aplicar el 10,5 % durante tres años.

Las funciones `READS SQL DATA` dependen de los datos de la tabla `Transacciones`:

- `ObtenerTotalRetirosPeriodo(1, '2026-01-01', '2026-01-31')` devuelve la suma de los retiros de la cuenta 1 en enero, o `0.00` si no hay.
- `EvaluarElegibilidadCredito(cuenta_id)` devuelve la clasificación crediticia de cada cuenta según su saldo y sus retiros.

## Checklist de requisitos

- [x] Función `DETERMINISTIC` de cálculo matemático (`CalcularImpuestoGMF`)
- [x] Función `READS SQL DATA` con rango de fechas (`ObtenerTotalRetirosPeriodo`)
- [x] Función `DETERMINISTIC` con bucle `WHILE` (`ProyectarRendimientoCDT`)
- [x] Función `READS SQL DATA` con reglas de negocio (`EvaluarElegibilidadCredito`)
- [x] Uso de `IFNULL` para manejar sumas vacías
- [x] Verificación de cuenta inexistente con retorno controlado
- [x] Estructuras de control `IF`, `ELSEIF` y `WHILE`
- [x] Consultas de prueba para cada función

## Referencias

Oracle. (s.f.-a). *CREATE PROCEDURE and CREATE FUNCTION statements*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/create-procedure.html

Oracle. (s.f.-b). *Flow control statements*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/flow-control-statements.html
