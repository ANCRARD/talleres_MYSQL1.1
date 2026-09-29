# Reto 1 MySQL II – Transferencia Bancaria Segura con Procedimientos Almacenados

**Estudiante:** Frank David Cuesta Niño
**Motor:** MySQL 8.0.46 (contenedor Docker)
**Cliente:** DBeaver 26.2

## Descripción

Implementación de una transferencia bancaria segura mediante el procedimiento almacenado `TransferirFondos`. La operación usa transacciones (`START TRANSACTION`, `COMMIT`, `ROLLBACK`), bloqueo de filas (`SELECT ... FOR UPDATE`), manejo de errores (`DECLARE EXIT HANDLER FOR SQLEXCEPTION`) y registro de auditoría, de modo que el dinero nunca se pierda: la transferencia ocurre completa o no ocurre.

## Estructura del repositorio

```
├── README.md
├── sql/
│   ├── reto1_bancodb.sql             Script completo
│   └── reto1_bancodb_comentado.sql   Versión comentada
├── capturas/
│   ├── 01_estructura/
│   ├── 02_procedimiento/
│   ├── 03_transferencia_exitosa/
│   ├── 04_transferencia_fallida/
│   ├── 05_prueba_handler/
│   ├── 06_desafio_extra/
│   └── 07_auditoria/
└── docs/
    └── Reto1_MySQL_II.pdf            Enunciado
```

## Cómo ejecutar

1. Abrir `sql/reto1_bancodb.sql` en un SQL Editor de DBeaver conectado a MySQL.
2. Ejecutar el script completo con **Alt + X**, sin seleccionar texto.
3. Cada consulta de verificación abre su propia pestaña de resultados.

> **Nota sobre Docker:** el contenedor trabaja en UTC. Por eso, el script inicia con `SET time_zone = '-05:00';`, que muestra las fechas del historial en hora de Colombia.

## Códigos de respuesta

| Código | Significado | Qué ocurre |
|---|---|---|
| 200 | Transferencia exitosa | Resta, suma, registra en historial y `COMMIT` |
| 400 | Saldo insuficiente o cuenta origen inexistente | `ROLLBACK`, no se modifica nada |
| 401 | Monto inválido (≤ 0 o nulo), desafío extra | Se rechaza antes de iniciar la transacción |
| 500 | Error de base de datos | El handler ejecuta `ROLLBACK` |

Estos códigos son una convención del ejercicio, inspirada en los códigos HTTP; MySQL no los define.

## Explicación por bloques

**1. Base de datos y tablas.** `cuentas` guarda el saldo actual de cada titular y `historial_transferencias` funciona como auditoría. El saldo usa `DECIMAL(10,2)` porque almacena valores exactos, mientras que `FLOAT` introduce errores de redondeo. Ambas tablas usan InnoDB, el motor de MySQL que soporta transacciones y bloqueo de filas.

**2. Parámetros.** `IN` recibe origen, destino y monto. `OUT` devuelve el código de respuesta en una variable de sesión (`@codigo`).

**3. Manejo de errores.** `DECLARE EXIT HANDLER FOR SQLEXCEPTION` captura cualquier error técnico, ejecuta `ROLLBACK`, devuelve 500 y sale del procedimiento.

**4. Transacción y bloqueo.** `START TRANSACTION` vuelve provisionales todos los cambios. `SELECT ... FOR UPDATE` lee el saldo y bloquea la fila de la cuenta origen, de modo que dos transferencias simultáneas no puedan gastar el mismo saldo.

**5. Validación.** Si la cuenta origen no existe o el saldo es menor que el monto, se ejecuta `ROLLBACK` y se devuelve 400. Esta validación es necesaria porque, para MySQL, restar hasta un saldo negativo no es un error.

**6. Transferencia.** Se resta al origen, se suma al destino, se registra en el historial y se ejecuta `COMMIT`.

**7. Desafío extra.** Se valida el monto antes de la transacción (401), se devuelve el titular origen como parámetro `OUT` y se registra el usuario responsable con `USER()`.

---

## Evidencias

Estado inicial de las cuentas: **Ana López 5000.00** y **Carlos Pérez 3000.00** (total del sistema: 8000). En todas las pruebas, la suma de ambos saldos se mantiene en 8000, lo que demuestra que el dinero nunca se crea ni se pierde.

### 1. Tablas creadas

Tablas de la base `BancoDB`:

![SHOW TABLES](capturas/01_estructura/01_show_tables.png)

Estructura de `cuentas`: `id_cuenta` como clave primaria y `saldo` como `decimal(10,2)`.

![DESCRIBE cuentas](capturas/01_estructura/02_describe_cuentas.png)

Estructura de `historial_transferencias`: `id_transferencia` con `auto_increment` y `fecha` con `CURRENT_TIMESTAMP`.

![DESCRIBE historial](capturas/01_estructura/03_describe_historial.png)

### 2. Procedimiento almacenado

El procedimiento `TransferirFondos` aparece registrado en `BancoDB`:

![Procedure status](capturas/02_procedimiento/04_procedure_status.png)

Código del procedimiento consultado con `SHOW CREATE PROCEDURE`:

![Código del procedimiento](capturas/02_procedimiento/05_show_create_procedure.png)

### 3. Transferencia exitosa

`CALL TransferirFondos(1, 2, 1000, @codigo);` devuelve **200**. Ana pasa de 5000 a **4000** y Carlos de 3000 a **4000**.

![Saldos tras la primera transferencia](capturas/03_transferencia_exitosa/06_saldos_primera_transferencia.png)

La prueba exitosa se ejecutó una segunda vez, lo que confirma que el procedimiento funciona de forma repetible: Ana pasa a **3000** y Carlos a **5000**.

![Segunda transferencia](capturas/03_transferencia_exitosa/07_segunda_transferencia.png)

### 4. Transferencia fallida por saldo insuficiente

`CALL TransferirFondos(1, 2, 10000, @codigo, @titular);` devuelve **400**, porque Ana no tiene saldo suficiente. El procedimiento ejecuta `ROLLBACK` y ningún saldo se modifica.

![Código 400](capturas/04_transferencia_fallida/08_codigo_400.png)
![Saldos sin cambios](capturas/04_transferencia_fallida/09_saldos_sin_cambios.png)

### 5. Prueba del handler (error de base de datos)

Para comprobar el `DECLARE EXIT HANDLER` de forma controlada, se oculta temporalmente la tabla de auditoría (`RENAME TABLE`). Así, los dos `UPDATE` se ejecutan, pero el `INSERT` falla. El handler ejecuta `ROLLBACK` y devuelve **500**.

![Código 500](capturas/05_prueba_handler/10_handler_codigo_500.png)

Los saldos se mantienen iguales a los de antes de la prueba: los `UPDATE` que sí alcanzaron a ejecutarse fueron deshechos. Al final, la tabla se restaura a su nombre original.

![Saldos sin cambios tras el error](capturas/05_prueba_handler/11_handler_saldos_sin_cambios.png)

### 6. Desafío extra

**Usuario responsable.** Se agrega la columna `usuario` a la tabla de auditoría:

![ALTER TABLE](capturas/06_desafio_extra/12_alter_table_usuario.png)
![Columna usuario](capturas/06_desafio_extra/13_describe_con_usuario.png)

**Monto inválido.** `CALL TransferirFondos(1, 2, 0, @codigo, @titular);` devuelve **401**. El titular queda en `NULL` porque el procedimiento se detiene antes de consultar la cuenta.

![Monto inválido 401](capturas/06_desafio_extra/14_monto_invalido_401.png)

**Titular origen como parámetro OUT.** `CALL TransferirFondos(1, 2, 500, @codigo, @titular);` devuelve **200** y el titular **Ana López**.

![Código 200 y titular](capturas/06_desafio_extra/15_codigo_200_titular.png)

### 7. Registro de auditoría

El historial registra cada transferencia exitosa con origen, destino, monto y fecha. Las pruebas fallidas (400, 401 y 500) no dejaron ningún registro. La última fila, hecha con el procedimiento del desafío extra, registra además el usuario responsable (`root@172.19.0.1`, la dirección con la que la red de Docker identifica al cliente DBeaver).

![Historial de auditoría](capturas/07_auditoria/16_historial_auditoria.png)

---

## Checklist de requisitos

- [x] Base de datos `BancoDB`
- [x] Tabla `cuentas` (`id_cuenta` PK, `titular`, `saldo DECIMAL(10,2)`)
- [x] Tabla `historial_transferencias` (`AUTO_INCREMENT`, `DEFAULT CURRENT_TIMESTAMP`)
- [x] Datos de prueba: Ana López 5000, Carlos Pérez 3000
- [x] Procedimiento `TransferirFondos` con parámetros `IN` y `OUT`
- [x] `DECLARE EXIT HANDLER FOR SQLEXCEPTION` con `ROLLBACK` → 500
- [x] `START TRANSACTION`
- [x] `SELECT ... FOR UPDATE` para consultar el saldo
- [x] Validación de saldo → `ROLLBACK` y 400
- [x] Resta, suma, registro en historial, `COMMIT` → 200
- [x] Prueba exitosa (1000) → 200
- [x] Prueba fallida (10000) → 400
- [x] Evidencia de auditoría
- [x] Desafío: monto ≤ 0 → 401
- [x] Desafío: parámetro `OUT` con el titular origen
- [x] Desafío: usuario responsable registrado
