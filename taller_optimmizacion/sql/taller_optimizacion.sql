USE BancoDB;

SET time_zone = '-05:00';

ALTER TABLE cuentas
    MODIFY COLUMN id_cuenta INT NOT NULL AUTO_INCREMENT,
    ADD COLUMN tipo_cuenta VARCHAR(20) NOT NULL DEFAULT 'Ahorros' AFTER titular,
    ADD COLUMN estado VARCHAR(20) NOT NULL DEFAULT 'Activa' AFTER saldo,
    ADD COLUMN fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER estado;

ALTER TABLE historial_transferencias
    ADD COLUMN estado_transferencia VARCHAR(20) NOT NULL DEFAULT 'Exitosa' AFTER monto,
    ADD CONSTRAINT fk_historial_origen FOREIGN KEY (cuenta_origen) REFERENCES cuentas (id_cuenta),
    ADD CONSTRAINT fk_historial_destino FOREIGN KEY (cuenta_destino) REFERENCES cuentas (id_cuenta);

DESCRIBE cuentas;
DESCRIBE historial_transferencias;
SELECT * FROM cuentas;

DROP PROCEDURE IF EXISTS cargar_datos_prueba;

DELIMITER //

CREATE PROCEDURE cargar_datos_prueba()
BEGIN
    DECLARE i INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    WHILE i <= 1000 DO
        INSERT INTO cuentas (titular, tipo_cuenta, saldo, estado, fecha_apertura)
        VALUES (
            CONCAT('Cliente_', i),
            IF(i % 2 = 0, 'Ahorros', 'Corriente'),
            ROUND(RAND() * 10000000, 2),
            IF(i % 10 = 0, 'Bloqueada', 'Activa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
    END WHILE;

    SET i = 1;

    WHILE i <= 10000 DO
        INSERT INTO historial_transferencias (cuenta_origen, cuenta_destino, monto, estado_transferencia, fecha)
        VALUES (
            FLOOR(1 + RAND() * 999),
            FLOOR(1 + RAND() * 999),
            ROUND(1000 + RAND() * 500000, 2),
            IF(i % 15 = 0, 'Fallida', 'Exitosa'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 180) DAY)
        );
        SET i = i + 1;
    END WHILE;

    COMMIT;
END //

DELIMITER ;

CALL cargar_datos_prueba();

DROP PROCEDURE IF EXISTS cargar_datos_prueba;

ANALYZE TABLE cuentas, historial_transferencias;

SELECT COUNT(*) AS total_cuentas FROM cuentas;
SELECT COUNT(*) AS total_transferencias FROM historial_transferencias;
SELECT estado_transferencia, COUNT(*) AS cantidad FROM historial_transferencias GROUP BY estado_transferencia;

EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
    AND fecha >= '2026-01-01 00:00:00';

CREATE INDEX idx_transf_estado_fecha ON historial_transferencias (estado_transferencia, fecha);

EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Exitosa'
    AND fecha >= '2026-01-01 00:00:00';

EXPLAIN ANALYZE
SELECT id_transferencia, cuenta_origen, monto, fecha
FROM historial_transferencias
WHERE estado_transferencia = 'Fallida'
    AND fecha >= '2026-01-01 00:00:00';

EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE DATE(fecha) = '2026-02-15';

EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE fecha >= '2026-02-15 00:00:00'
    AND fecha < '2026-02-16 00:00:00';

CREATE INDEX idx_transf_fecha ON historial_transferencias (fecha);

EXPLAIN ANALYZE
SELECT *
FROM historial_transferencias
WHERE fecha >= '2026-02-15 00:00:00'
    AND fecha < '2026-02-16 00:00:00';

EXPLAIN
SELECT *
FROM cuentas
WHERE estado = 'Activa';

EXPLAIN
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

CREATE INDEX idx_cuentas_estado_cubriente ON cuentas (estado, tipo_cuenta, saldo, titular);

EXPLAIN
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

EXPLAIN ANALYZE
SELECT titular, saldo, tipo_cuenta
FROM cuentas
WHERE estado = 'Activa';

EXPLAIN
SELECT *
FROM cuentas
WHERE estado = 'Activa';

EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
    AND ht.monto > 300000.00;

EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
    AND ht.monto > 300000.00
    AND ht.fecha >= NOW() - INTERVAL 30 DAY;

CREATE INDEX idx_transf_fecha_monto_origen ON historial_transferencias (fecha, monto, cuenta_origen);

DROP INDEX idx_transf_fecha ON historial_transferencias;

EXPLAIN ANALYZE
SELECT c.id_cuenta, c.titular, ht.id_transferencia, ht.monto, ht.fecha
FROM cuentas c
JOIN historial_transferencias ht ON c.id_cuenta = ht.cuenta_origen
WHERE c.estado = 'Activa'
    AND ht.monto > 300000.00
    AND ht.fecha >= NOW() - INTERVAL 30 DAY;

SHOW INDEX FROM historial_transferencias;
SHOW INDEX FROM cuentas;

CALL TransferirFondos(1, 2, 100, @codigo, @titular);
SELECT @codigo, @titular;
SELECT * FROM historial_transferencias ORDER BY id_transferencia DESC LIMIT 1;
