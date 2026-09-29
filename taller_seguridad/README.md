# Taller de Seguridad, Permisos y Prevención de SQL Injection en MySQL (BancoDB)

**Estudiante:** Frank David Cuesta Niño
**Motor:** MySQL 8.0.46 (contenedor Docker)
**Cliente:** DBeaver 26.2

## Descripción

Configuración de seguridad sobre la base `BancoDB` mediante la creación de usuarios por roles, la asignación granular de privilegios con `GRANT`, la revocación con `REVOKE` y la prevención de inyección SQL con sentencias preparadas. El taller trabaja sobre la base real del Reto 1, cuyas tablas ya existen y contienen datos. Por lo tanto, se omiten la creación de tablas y los datos de ejemplo del enunciado, y el trabajo se concentra en la capa de usuarios y permisos.

## Cómo ejecutar

1. Abrir `sql/taller2_limpio.sql` en un SQL Editor de DBeaver conectado como `root`.
2. Ejecutar el script completo con **Alt + X**. Las sentencias `GRANT`, `REVOKE` y `SHOW GRANTS` se ejecutan sobre la conexión de `root`, de modo que no requieren iniciar sesión con los usuarios creados.
3. Probar los permisos de cada usuario **desde la terminal**, no desde DBeaver. Los usuarios se crearon como `@'localhost'`, mientras que DBeaver se conecta a través de la red de Docker (`172.19.0.1`). En consecuencia, esos usuarios solo pueden autenticarse dentro del contenedor.

### Pruebas de permisos en la terminal

Ingresar al cliente `mysql` dentro del contenedor con el usuario cajero:

```bash
docker exec -it <contenedor> mysql -u cajero_app -p
```

Ya autenticado, ejecutar cada prueba y observar el error esperado:

```sql
USE BancoDB;
SELECT id_cuenta, titular, saldo FROM cuentas LIMIT 3;
SELECT estado FROM cuentas LIMIT 3;
UPDATE cuentas SET saldo = 0 WHERE id_cuenta = 1;
```

El primer `SELECT` funciona, porque el cajero tiene permiso sobre esas columnas. Sin embargo, el `SELECT estado` falla con el error **1143**, ya que `estado` no está entre sus columnas autorizadas. Además, el `UPDATE` sobre `saldo` también falla con el error **1143**, porque ese privilegio se revocó justo antes.

## Explicación por bloques

**1. Higiene de seguridad.** Se eliminan los usuarios anónimos (`''@'localhost'` y `''@'%'`), que representan un riesgo porque permiten conexiones sin identidad definida.

**2. Creación de usuarios por roles.** Se crean cuatro usuarios que representan perfiles distintos: un administrador local, un cajero con acceso restringido, un auditor remoto de solo lectura y una aplicación backend. Cada uno se define con el formato `'usuario'@'host'`, de modo que el host forma parte de la identidad.

**3. Asignación granular de privilegios.** El administrador recibe todos los privilegios con `WITH GRANT OPTION`. Además, el backend recibe operaciones DML (`SELECT`, `INSERT`, `UPDATE`), mientras que el cajero recibe permisos a nivel de columna sobre `cuentas`. Por su parte, el auditor recibe solo lectura sobre todo el esquema.

**4. Verificación y revocación.** Se consultan los privilegios con `SHOW GRANTS` y se revoca el permiso de actualización del cajero. No obstante, la revocación debe hacerse a nivel de columna con `REVOKE UPDATE (saldo)`, tal como se otorgó.

**5. Prevención de SQL Injection.** Se declara una sentencia preparada con marcadores `?`, se definen variables de sesión y se ejecuta de forma segura con `EXECUTE ... USING`. Por lo tanto, los valores nunca se concatenan directamente en la cadena SQL, lo que impide la inyección. Finalmente, la sentencia se libera con `DEALLOCATE PREPARE`.

## Respuestas a las preguntas teóricas

**¿Por qué `REVOKE UPDATE ON tabla` falla con el error 1147?**
El privilegio de actualización se otorgó al cajero a nivel de columna, con `UPDATE (saldo)`. Por lo tanto, para revocarlo se debe especificar la misma granularidad con `REVOKE UPDATE (saldo)`. Si se intenta revocar `UPDATE` sobre toda la tabla, MySQL responde el error **1147**, porque nunca existió un privilegio de tabla que revocar, sino uno de columna (Oracle, s.f.-b).

**¿Por qué `FLUSH PRIVILEGES` no es necesario después de `GRANT`?**
Las sentencias `GRANT`, `REVOKE`, `CREATE USER` y `DROP USER` modifican las tablas de privilegios y recargan esos cambios en memoria de forma automática. En consecuencia, `FLUSH PRIVILEGES` solo se necesita cuando se editan directamente las tablas del esquema `mysql` con `INSERT` o `UPDATE` manuales, algo que este taller no hace (Oracle, s.f.-a).

## Resultados esperados

- `SHOW GRANTS` del cajero muestra `SELECT (id_cuenta, titular, saldo)` y `UPDATE (saldo)` antes de la revocación, y solo el `SELECT` de columnas después.
- El administrador aparece con `GRANT ALL PRIVILEGES ... WITH GRANT OPTION` y el auditor con `SELECT` sobre todo el esquema.
- En la terminal, el cajero puede consultar `id_cuenta`, `titular` y `saldo`, pero recibe el error 1143 al leer `estado` y al intentar actualizar `saldo`.
- La sentencia preparada devuelve la cuenta con `id_cuenta = 1` y `estado = 'Activa'`.

## Checklist de requisitos

- [x] Uso de `BancoDB` (corrección de `BancoBD`)
- [x] Eliminación de usuarios anónimos
- [x] Creación de los cuatro usuarios por roles
- [x] Privilegios totales al administrador con `WITH GRANT OPTION`
- [x] Privilegios DML al backend
- [x] Privilegios a nivel de columna al cajero
- [x] Solo lectura al auditor
- [x] `SHOW GRANTS` de cada usuario
- [x] `REVOKE UPDATE (saldo)` a nivel de columna
- [x] Pruebas de permisos en terminal con los errores 1143
- [x] Sentencia preparada con `PREPARE`, `EXECUTE` y `DEALLOCATE`
- [x] Explicación de por qué `FLUSH PRIVILEGES` no es necesario

## Referencias

Oracle. (s.f.-a). *GRANT statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/grant.html

Oracle. (s.f.-b). *REVOKE statement*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/revoke.html

Oracle. (s.f.-c). *SQL prepared statements*. En *MySQL 8.0 reference manual*. https://dev.mysql.com/doc/refman/8.0/en/sql-prepared-statements.html
