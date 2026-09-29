# Taller de Triggers y Eventos en MySQL (BancoDB)

**Estudiante:** Frank David Cuesta Niño
**Motor:** MySQL 8.0.46 (contenedor Docker)
**Cliente:** DBeaver 26.2

## Descripción

Implementación de reactividad en tiempo real con triggers y de tareas programadas con eventos sobre la base `BancoDB`. Se crean tablas de soporte para auditoría y métricas, un trigger de auditoría de saldos, un trigger de validación de transferencias y dos eventos programados. Además, el taller demuestra cómo los triggers interactúan con el procedimiento `TransferirFondos` del Reto 1.

## Cómo ejecutar

1. Abrir `sql/taller3_limpio.sql` en un SQL Editor de DBeaver conectado como `root`.
2. Ejecutar el script completo con **Alt + X**. Los bloques de creación usan `DELIMITER //`, de modo que deben ejecutarse tal cual, sin seleccionar solo una línea.
3. Verificar los resultados de auditoría, la prueba del `SIGNAL` y el estado de los eventos en las pestañas de resultados.

> **Nota sobre el `event_scheduler`:** el script usa `SET PERSIST event_scheduler = ON`, de modo que el programador de eventos permanece encendido aunque se reinicie el contenedor. Por el contrario, `SET GLOBAL` se pierde al reiniciar.

## Explicación por bloques

**1. Tablas de soporte.** Se crean `auditoria_saldos`, que registra cada cambio de saldo, y `metricas_diarias`, que consolida el total de cuentas activas y el saldo del sistema. Ambas usan `CREATE TABLE IF NOT EXISTS`, de modo que el script es repetible sin error.

**2. Trigger de auditoría (`AFTER UPDATE`).** Este trigger captura los valores previos (`OLD`) y nuevos (`NEW`) del saldo cada vez que se actualiza una cuenta, y solo registra si hubo un cambio efectivo. Además, guarda el usuario responsable con `USER()`.

**3. Evento de métricas.** El evento `evt_registrar_metricas_diarias` se ejecuta cada día y consolida las métricas del sistema como una tarea asíncrona en segundo plano.

**4. Trigger de validación (`BEFORE INSERT`).** El trigger `trg_validar_transferencia` valida dos reglas de negocio antes de insertar en `historial_transferencias`: el monto debe ser mayor a cero, y la cuenta de origen no puede ser igual a la de destino. Si alguna falla, aborta la operación con `SIGNAL SQLSTATE '45000'` y un mensaje explicativo.

**5. Evento de inactivación.** El evento `evt_inactivar_cuentas_vacias` se ejecuta cada día y cambia a `'Inactiva'` toda cuenta activa cuyo saldo sea cero.

**6. Pruebas.** El script demuestra las interacciones descritas en las respuestas teóricas: el disparo del trigger de auditoría a través de `TransferirFondos`, la captura del `SIGNAL` por el handler del procedimiento y la lógica del evento de inactivación.

## Respuestas a las preguntas teóricas

**El trigger `AFTER UPDATE` también se dispara con `TransferirFondos`.**
Al llamar `TransferirFondos(1, 2, 300, ...)`, el procedimiento actualiza el saldo de la cuenta de origen y el de la de destino. Por lo tanto, el trigger `trg_auditar_cambio_saldo` se dispara dos veces y genera dos filas en `auditoria_saldos`, una por cada cuenta. Esto demuestra que los triggers reaccionan a cualquier `UPDATE`, incluso a los que ocurren dentro de un procedimiento almacenado.

**El `SIGNAL` dentro de `TransferirFondos` devuelve el código 500.**
Al llamar `TransferirFondos(1, 1, 100, ...)` con origen y destino iguales, el `INSERT` en el historial dispara el `SIGNAL` del trigger de validación. Sin embargo, el `DECLARE EXIT HANDLER FOR SQLEXCEPTION` del procedimiento captura esa excepción como cualquier otra, ejecuta `ROLLBACK` y devuelve **500**. En consecuencia, el mensaje personalizado del trigger no llega al usuario final, porque el control de errores del procedimiento tiene prioridad. El trigger sigue protegiendo las inserciones directas.

**Cómo probar el evento sin esperar una semana.**
Para verificar el efecto sin depender del reloj, se inserta una cuenta de prueba con saldo cero y se ejecuta la misma sentencia que corre el evento, de modo que su estado pasa de `'Activa'` a `'Inactiva'`. Además, se confirma que el evento existe y está habilitado con `SHOW EVENTS` y con `information_schema.EVENTS`, donde `last_executed` muestra la última ejecución automática.

## Resultados esperados

- Un `UPDATE` directo sobre el saldo de una cuenta genera una fila en `auditoria_saldos` con el saldo anterior, el nuevo y el usuario.
- `TransferirFondos(1, 2, 300, ...)` devuelve el código 200 y produce dos filas de auditoría, una por la cuenta de origen y otra por la de destino.
- `TransferirFondos(1, 1, 100, ...)` devuelve el código 500, porque el `SIGNAL` del trigger es capturado por el handler del procedimiento.
- La cuenta de prueba con saldo cero pasa de `'Activa'` a `'Inactiva'` al aplicar la lógica del evento.
- `SHOW EVENTS` e `information_schema.EVENTS` muestran los dos eventos con estado `ENABLED`.

## Checklist de requisitos

- [x] `SET PERSIST event_scheduler = ON`
- [x] Tablas de soporte `auditoria_saldos` y `metricas_diarias`
- [x] Trigger `AFTER UPDATE` de auditoría de saldos
- [x] Evento diario de métricas del sistema
- [x] Trigger `trg_validar_transferencia` (`BEFORE INSERT`) con las dos reglas de negocio
- [x] Uso de `SIGNAL SQLSTATE '45000'` con mensaje explicativo
- [x] Evento `evt_inactivar_cuentas_vacias`
- [x] Demostración del trigger de auditoría vía `TransferirFondos`
- [x] Prueba del `SIGNAL` capturado por el handler (código 500)
- [x] Verificación del evento con `SHOW EVENTS` e `information_schema.EVENTS`

## Referencias

Oracle. (s.f.-a). *CREATE EVENT statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/create-event.html

Oracle. (s.f.-b). *CREATE TRIGGER statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/create-trigger.html

Oracle. (s.f.-c). *SIGNAL statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/signal.html
