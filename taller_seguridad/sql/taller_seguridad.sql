USE BancoDB;

DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';

DROP USER IF EXISTS 'admin_banco'@'localhost';
DROP USER IF EXISTS 'cajero_app'@'localhost';
DROP USER IF EXISTS 'auditor_consulta'@'%';
DROP USER IF EXISTS 'app_backend'@'localhost';

CREATE USER 'admin_banco'@'localhost' IDENTIFIED BY 'AdminBank2026!#';
CREATE USER 'cajero_app'@'localhost' IDENTIFIED BY 'CajeroPass2026!';
CREATE USER 'auditor_consulta'@'%' IDENTIFIED BY 'AuditorPass2026!';
CREATE USER 'app_backend'@'localhost' IDENTIFIED BY 'AppBackend2026!Sec';

GRANT ALL PRIVILEGES ON BancoDB.* TO 'admin_banco'@'localhost' WITH GRANT OPTION;

GRANT SELECT, INSERT, UPDATE ON BancoDB.* TO 'app_backend'@'localhost';

GRANT SELECT (id_cuenta, titular, saldo), UPDATE (saldo) ON BancoDB.cuentas TO 'cajero_app'@'localhost';

GRANT SELECT ON BancoDB.* TO 'auditor_consulta'@'%';

SHOW GRANTS FOR 'admin_banco'@'localhost';
SHOW GRANTS FOR 'cajero_app'@'localhost';
SHOW GRANTS FOR 'auditor_consulta'@'%';
SHOW GRANTS FOR 'app_backend'@'localhost';

REVOKE UPDATE (saldo) ON BancoDB.cuentas FROM 'cajero_app'@'localhost';

SHOW GRANTS FOR 'cajero_app'@'localhost';

PREPARE stmt_buscar_cuenta FROM
'SELECT id_cuenta, titular, saldo, estado FROM cuentas WHERE id_cuenta = ? AND estado = ?';

SET @id_busqueda = 1;
SET @estado_busqueda = 'Activa';

EXECUTE stmt_buscar_cuenta USING @id_busqueda, @estado_busqueda;

DEALLOCATE PREPARE stmt_buscar_cuenta;
