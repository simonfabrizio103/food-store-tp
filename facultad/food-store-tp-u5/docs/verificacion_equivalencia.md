# Parte D — Anonimización y verificación de equivalencia

**Fecha:** 8 de noviembre de 2026  
**Motor:** PostgreSQL 18 — base `postgres` (`localhost:5432`)  
**Scripts:** `sql/usuario_anon.sql`, `sql/verificar_equivalencia_anon.sql`

---

## 1. Qué se anonimizó y qué se conservó

Se construyó `usuario_anon` como una **pseudonimización** de `usuario`: se destruyen los datos personales directos y se preservan los atributos con valor analítico.

| Columna original | Tratamiento | Columna en `usuario_anon` | Motivo |
|------------------|-------------|---------------------------|--------|
| `id` | Se conserva | `id` | Permite mantener los joins con `pedido.usuario_id`; es un identificador interno, no un dato personal. |
| `email` | Seudónimo determinístico `u_<md5(id‖sal)>@anon.example` | `email_pseud` | Rompe el vínculo con la persona y, a la vez, es estable entre corridas (permite re-identificar registros dentro del dataset sin conocer la sal). |
| `nombre` | Se descarta y se reemplaza por `Anon-000N` | `nombre_pseud` | El nombre completo es un identificador directo. |
| `rol` | Se conserva | `rol` | Atributo de negocio necesario para reportes. |
| `fecha_alta` | Se conserva | `fecha_alta` | Atributo temporal necesario para análisis de cohortes. |
| `activo` | Se conserva | `activo` | Atributo de negocio. |
| `password_hash` | **No se copia** | — | No tiene utilidad analítica y es material sensible. |

**Detalle técnico:** el seudónimo depende de `id` y de una sal fija del TP (`food-store-u5-2026`) procesadas con `md5()` (builtin, sin extensiones). Sin la sal, el hash no es reversible por diccionario trivial, pero **no debe considerarse cifrado**: es una función de hash rápida. En producción se usaría HMAC-SHA256 con una clave gestionada (KMS/Vault) y una sal rotable.

`usuario_anon` se recrea con `DROP TABLE IF EXISTS` + `CREATE TABLE` + `INSERT ... SELECT`, por lo que el script es idempotente y sirve para refrescar la anonimización cuando cambie `usuario`. Se otorgó `SELECT` a `rol_app_lectura`, `rol_reportes`, `rol_soporte` y `rol_app_escritura`.

---

## 2. Resultados de las verificaciones (salida real)

### D.1 — Volumen
```
 filas_usuario | filas_usuario_anon | equivalente
---------------+--------------------+-------------
             6 |                  6 | t
```

### D.2 — Distribución por rol
```
    origen    |   rol    | count
--------------+----------+-------
 usuario      | admin    |     1
 usuario_anon | admin    |     1
 usuario      | reportes |     1
 usuario_anon | reportes |     1
 usuario      | soporte  |     1
 usuario_anon | soporte  |     1
 usuario      | vendedor |     3
 usuario_anon | vendedor |     3
```

### D.3 — Distribución por activo
```
    origen    | activo | count
--------------+--------+-------
 usuario      | f      |     1
 usuario_anon | f      |     1
 usuario      | t      |     5
 usuario_anon | t      |     5
```

### D.4 — Distribución por año de alta
```
    origen    | anio | count
--------------+------+-------
 usuario      | 2024 |     6
 usuario_anon | 2024 |     6
```

### D.5 — Comparación exacta por `id`
```
 diferencias
-------------
           0
```
Ningún registro difiere en `rol`, `fecha_alta` ni `activo`, y ambos conjuntos de `id` son idénticos (no hay filas huérfanas en ninguno de los dos lados).

### D.6 — Utilidad analítica: pedidos por rol (join con `pedido`)
```
    origen    |   rol    | pedidos
--------------+----------+---------
 usuario      | admin    |       0
 usuario_anon | admin    |       0
 usuario      | reportes |       0
 usuario_anon | reportes |       0
 usuario      | soporte  |       0
 usuario_anon | soporte  |       0
 usuario      | vendedor |       5
 usuario_anon | vendedor |       5
```
El join `pedido.usuario_id → usuario_anon.id` reproduce exactamente los mismos agregados que contra `usuario`. **La analítica no pierde expresividad al usar la tabla anonimizada.**

### D.7 — Fuga de PII
```
 emails_reales | nombres_reales
---------------+----------------
             0 |              0
```
No quedan emails `@foodstore.com` ni nombres reales en `usuario_anon`.

### D.8 — Unicidad del pseudónimo
```
 total | distintos
-------+-----------
     6 |         6
```

### D.9 — k-anonimato aproximado por `(rol, año_alta)`
```
   rol    | anio | k
----------+------+---
 admin    | 2024 | 1
 reportes | 2024 | 1
 soporte  | 2024 | 1
 vendedor | 2024 | 3
```

---

## 3. Conclusión de equivalencia

| Criterio | Resultado |
|----------|-----------|
| Mismo volumen | ✅ 6 = 6 |
| Misma distribución de `rol` | ✅ idéntica |
| Misma distribución de `activo` | ✅ idéntica |
| Misma distribución de `fecha_alta` | ✅ idéntica |
| Mismos agregados al unir con `pedido` | ✅ idénticos |
| Sin PII directa (`email`, `nombre`) | ✅ 0 coincidencias |
| `id` preservado y consistente | ✅ 0 diferencias |

**La tabla `usuario_anon` es equivalente a `usuario` para fines analíticos** (conteos, distribuciones, joins por usuario y agregados por rol) y **no contiene datos personales directos**. No es equivalente para fines operativos: no permite iniciar sesión, enviar emails ni recuperar el nombre real.

---

## 4. Limitación: k-anonimato bajo

La verificación D.9 muestra `k = 1` para los roles `admin`, `reportes` y `soporte`: en un dataset de 6 personas, la combinación `(rol, año_alta)` identifica de forma única a esos individuos. Si un atacante tuviera información auxiliar (“el administrador se dio de alta en 2024”), podría re-identificarlos **sin necesidad del email**. Esto es inherente al tamaño mínimo del dataset del TP y no invalida la pseudonimización, pero en un dataset real habría que:

1. **Generalizar** `fecha_alta` (por ejemplo, solo `año` o `trimestre`) y `rol` (agrupar roles poco frecuentes en `otros`).
2. **Suprimir** o agrupar las categorías con `k < 3` (regla `k ≥ 3`).
3. Evaluar `l-diversidad` y `t-cercanía` si se agregan atributos sensibles.
4. Documentar el análisis de riesgo de re-identificación antes de publicar el dataset.

Para el alcance de este TP, la tabla cumple el objetivo: demuestra que se puede **preservar la utilidad analítica y eliminar los identificadores directos**, y deja explícito el límite del k-anonimato con datasets pequeños.

---

## 5. Cómo reproducir

```powershell
$env:PGPASSWORD="postgres"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U postgres -d postgres `
    -f sql\usuario_anon.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U postgres -d postgres `
    -f sql\verificar_equivalencia_anon.sql
```

`usuario_anon.sql` es idempotente: se puede re-ejecutar cada vez que se actualice `usuario`.
