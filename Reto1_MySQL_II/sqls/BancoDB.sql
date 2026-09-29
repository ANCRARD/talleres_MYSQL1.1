CREATE DATABASE `BancoDB` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */
/*!80016 DEFAULT ENCRYPTION='N' */;

CREATE TABLE `cuentas` (
  `id_cuenta` int NOT NULL,
`titular` varchar(100) DEFAULT NULL,
`saldo` decimal(10, 2) DEFAULT NULL,
PRIMARY KEY (`id_cuenta`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `historial_transferencias` (
  `id_transferencia` int NOT NULL AUTO_INCREMENT,
`cuenta_origen` int DEFAULT NULL,
`cuenta_destino` int DEFAULT NULL,
`monto` decimal(10, 2) DEFAULT NULL,
`fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
`usuario` varchar(100) DEFAULT NULL,
PRIMARY KEY (`id_transferencia`)
) ENGINE = InnoDB AUTO_INCREMENT = 4 DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE DEFINER = `root` @`%` PROCEDURE `BancoDB`.`TransferirFondos`(
    IN p_origen INT,
    IN p_destino INT,
    IN p_monto DECIMAL(10, 2),
    OUT p_codigo_respuesta INT,
    OUT p_titular_origen VARCHAR(100)
)
proc: BEGIN
    DECLARE v_saldo DECIMAL(10, 2);

DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;

SET
p_codigo_respuesta = 500;
END;

IF p_monto IS NULL
OR p_monto <= 0 THEN
        SET
p_codigo_respuesta = 401;

LEAVE proc;
END IF;

START TRANSACTION;

SELECT
    saldo,
    titular
INTO
    v_saldo,
    p_titular_origen
FROM
    cuentas
WHERE
    id_cuenta = p_origen
    FOR
UPDATE;
    
    IF v_saldo IS NULL
    OR v_saldo < p_monto THEN
        ROLLBACK;

SET
p_codigo_respuesta = 400;
ELSE
        UPDATE
    cuentas
SET
    saldo = saldo - p_monto
WHERE
    id_cuenta = p_origen;

UPDATE
    cuentas
SET
    saldo = saldo + p_monto
WHERE
    id_cuenta = p_destino;

INSERT
    INTO
    historial_transferencias
            (cuenta_origen,
    cuenta_destino,
    monto,
    usuario)
VALUES (p_origen,
p_destino,
p_monto,
USER());

COMMIT;

SET
p_codigo_respuesta = 200;
END IF;
END proc;

CREATE DATABASE `BancoDB` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */
/*!80016 DEFAULT ENCRYPTION='N' */;
