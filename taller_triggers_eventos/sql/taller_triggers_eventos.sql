USE BancoDB;

SET PERSIST event_scheduler = ON;

CREATE TABLE IF NOT EXISTS auditoria_saldos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cuenta INT NOT NULL,
    saldo_anterior DECIMAL(10,2) NOT NULL,
    saldo_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cuenta) REFERENCES cuentas (id_cuenta)
);

CREATE TABLE IF NOT EXISTS metricas_diarias (
    id_metrica INT AUTO_INCREMENT PRIMARY KEY,
    fecha_metrica DATE NOT NULL,
    total_cuentas INT NOT NULL,
    saldo_total_sistema DECIMAL(12,2) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

DROP TRIGGER IF EXISTS trg_auditar_cambio_saldo //

CREATE TRIGGER trg_auditar_cambio_saldo
AFTER UPDATE ON cuentas
FOR EACH ROW
BEGIN
    IF OLD.saldo <> NEW.saldo THEN
        INSERT INTO auditoria_saldos (id_cuenta, saldo_anterior, saldo_nuevo, usuario)
        VALUES (NEW.id_cuenta, OLD.saldo, NEW.saldo, USER());
    END IF;
END //

DROP EVENT IF EXISTS evt_registrar_metricas_diarias //

CREATE EVENT evt_registrar_metricas_diarias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Consolida el saldo total y cantidad de cuentas activas diariamente'
DO
BEGIN
    INSERT INTO metricas_diarias (fecha_metrica, total_cuentas, saldo_total_sistema)
    SELECT CURDATE(), COUNT(id_cuenta), IFNULL(SUM(saldo), 0.00)
    FROM cuentas
    WHERE estado = 'Activa';
END //

DROP TRIGGER IF EXISTS trg_validar_transferencia //

CREATE TRIGGER trg_validar_transferencia
BEFORE INSERT ON historial_transferencias
FOR EACH ROW
BEGIN
    IF NEW.monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto de la transferencia debe ser mayor a cero';
    END IF;

    IF NEW.cuenta_origen = NEW.cuenta_destino THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen y destino no pueden ser iguales';
    END IF;
END //

DROP EVENT IF EXISTS evt_inactivar_cuentas_vacias //

CREATE EVENT evt_inactivar_cuentas_vacias
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
COMMENT 'Inactiva las cuentas activas cuyo saldo llega a cero'
DO
BEGIN
    UPDATE cuentas
    SET estado = 'Inactiva'
    WHERE saldo = 0.00
        AND estado = 'Activa';
END //

DELIMITER ;

UPDATE cuentas SET saldo = saldo + 500.00 WHERE id_cuenta = 1;
UPDATE cuentas SET saldo = saldo - 500.00 WHERE id_cuenta = 1;
SELECT * FROM auditoria_saldos ORDER BY id_log DESC;

CALL TransferirFondos(1, 2, 300.00, @codigo, @titular);
SELECT @codigo, @titular;
SELECT * FROM auditoria_saldos ORDER BY id_log DESC LIMIT 5;

CALL TransferirFondos(1, 1, 100.00, @codigo, @titular);
SELECT @codigo, @titular;

INSERT INTO cuentas (titular, tipo_cuenta, saldo, estado) VALUES ('Cuenta_Test_Vacia', 'Ahorros', 0.00, 'Activa');

SELECT id_cuenta, titular, saldo, estado FROM cuentas WHERE titular = 'Cuenta_Test_Vacia';

UPDATE cuentas
SET estado = 'Inactiva'
WHERE saldo = 0.00
    AND estado = 'Activa';

SELECT id_cuenta, titular, saldo, estado FROM cuentas WHERE titular = 'Cuenta_Test_Vacia';

SHOW EVENTS FROM BancoDB;

SELECT event_name, status, interval_value, interval_field, last_executed
FROM information_schema.EVENTS
WHERE event_schema = 'BancoDB';

SELECT * FROM metricas_diarias ORDER BY id_metrica DESC;
