# Ejercicio Lectura Crítica - Base de Datos II

## Script 1 - Dar de baja funciones de películas retiradas

**Script original:**
```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

**Qué filas afectaría realmente:**
Desactiva **TODAS** las filas de la tabla `funcion` (todas las funciones de todas las películas), sin distinguir si la película está retirada o vigente. Es un UPDATE sin WHERE masivo.

**Por qué no coincide con la consigna:**
La consigna dice "funciones de películas retiradas de cartel", pero el script no filtra por película ni por estado ni por fecha. Si se ejecuta fuera de transacción es destructivo e irreversible.

**Versión corregida (con WHERE):**
```sql
BEGIN;
UPDATE funcion SET activa = FALSE
WHERE id_pelicula IN (SELECT id_pelicula FROM pelicula WHERE estado = 'RETIRADA');
-- alternativa por fecha: WHERE fecha < CURRENT_DATE
SELECT * FROM funcion WHERE activa = FALSE; -- verificar filas
ROLLBACK; -- inspeccionar y luego COMMIT si es correcto
```

---

## Script 2 - Limpiar categorías sin productos asociados

**Script original:**
```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

**Qué filas afectaría realmente:**
Si la subconsulta `SELECT categoria_id FROM producto` devuelve al menos un `NULL` (categoria_id anulable), la condición `NOT IN` se evalúa a `UNKNOWN` para todas las filas y **NO BORRA NINGUNA** categoría, aunque haya categorías vacías. Es el bug clásico de `NOT IN` vs `NULL`.

**Por qué no coincide con la consigna:**
Debería borrar solo categorías sin productos, pero por el NULL no borra nada o borra de forma impredecible.

**Versión corregida (con NOT EXISTS y manejo de NULL):**
```sql
-- Opción correcta 1: NOT EXISTS (no afectada por NULL)
DELETE FROM categoria c
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria);

-- Opción correcta 2: filtrar NULLs en la subconsulta
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto WHERE categoria_id IS NOT NULL);
```
