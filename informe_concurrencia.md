# Informe Concurrencia - Food Store (food_store_copia)

## Escenario 1 - Lectura No Repetible
- **Escenario:** Lectura no repetible
- **Cómo se reprodujo:**
  Sesión A: `BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SELECT stock FROM producto WHERE id_producto=1;` -> 10
  Sesión B: `BEGIN; UPDATE producto SET stock=5 WHERE id_producto=1; COMMIT;`
  Sesión A: `SELECT stock FROM producto WHERE id_producto=1;` -> 5 ; `COMMIT;`
- **Qué se observó:** Primera lectura 10, segunda lectura 5 dentro de la misma transacción A con READ COMMITTED. Anomalía reproducida.
- **Explicación de la IA (OpenCode Big Pickle):** "Con READ COMMITTED cada SELECT ve lo último committeado. Con REPEATABLE READ ve snapshot al inicio y no ve el UPDATE de B."
- **Verificación en el motor:** Repetido con `BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ; SELECT 10` -> B UPDATE 5 COMMIT -> A SELECT 10 (no cambia). Confirmado.
- **Conclusión:** IA acertó. READ COMMITTED permite no repetible, REPEATABLE READ lo evita. Motor PostgreSQL MVCC lo confirmó.

## Escenario 2 - Lectura Fantasma
- **Cómo se reprodujo:**
  A: `BEGIN; SELECT COUNT(*) FROM producto WHERE activo=true;` -> 2
  B: `INSERT INTO producto (nombre, precio_lista, stock, id_categoria) VALUES ('Fantasma', 50, 1, 1); COMMIT;`
  A: `SELECT COUNT(*) FROM producto WHERE activo=true;` -> 3 ; `COMMIT;`
- **Qué se observó:** COUNT pasó de 2 a 3 dentro de misma transacción.
- **Explicación IA:** "REPEATABLE READ no evita fantasma en PG, necesita SERIALIZABLE o bloquear con FOR UPDATE / LOCK TABLE."
- **Verificación:** Repetido en REPEATABLE READ también dio 3 -> confirmada explicación. Solo SERIALIZABLE lo evitaría.
- **Conclusión:** IA acertó.

## Escenario 3 - Espera por Bloqueo FOR UPDATE
- **Cómo se reprodujo:**
  A: `BEGIN; SELECT * FROM producto WHERE id_producto=1 FOR UPDATE;` (bloquea)
  B: `BEGIN; SELECT * FROM producto WHERE id_producto=1 FOR UPDATE;` (queda esperando)
  A: `COMMIT;` -> B se desbloquea y devuelve fila.
- **Qué se observó:** B quedó en `waiting` hasta COMMIT de A.
- **Explicación IA:** "FOR UPDATE pone lock exclusivo de fila, segunda sesión espera. No es nivel de aislamiento, es bloqueo pesimista."
- **Verificación:** Probado tal cual, B esperó. Correcto.
- **Conclusión:** IA acertó. Mecanismo FOR UPDATE resuelve.

## DUIA Parte 2
Herramienta: OpenCode 1.18.27 + DBeaver 2 sesiones food_store_copia
Verificación: Los SELECT/UPDATE de arriba con stock 10->5 y COUNT 2->3