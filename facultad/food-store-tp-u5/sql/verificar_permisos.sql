-- ============================================================================
-- TP Unidad 5 — Parte A: Verificación de permisos
-- Ejecutar DESPUÉS de roles.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Listar roles con \du (equivalente SQL)
-- ----------------------------------------------------------------------------
SELECT rolname, rolcanlogin, rolcreaterole, rolcreatedb, rolsuper
FROM pg_roles
WHERE rolname IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','app_web','admin_datos')
ORDER BY rolname;

-- ----------------------------------------------------------------------------
-- 2. Verificar privilegios sobre tablas (information_schema.role_table_grants)
-- ----------------------------------------------------------------------------
SELECT
    grantee AS rol,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes')
ORDER BY grantee, table_name, privilege_type;

-- ----------------------------------------------------------------------------
-- 3. Verificar privilegios a nivel de columna sobre usuario.email
-- ----------------------------------------------------------------------------
SELECT
    grantee AS rol,
    column_name,
    privilege_type
FROM information_schema.role_column_grants
WHERE table_schema = 'public'
  AND table_name = 'usuario'
  AND column_name = 'email'
ORDER BY grantee;

-- ----------------------------------------------------------------------------
-- 4. Verificar herencia de roles (quién es miembro de quién)
-- ----------------------------------------------------------------------------
SELECT
    r.rolname AS rol_miembro,
    m.rolname AS rol_padre
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.member
JOIN pg_roles m ON m.oid = am.roleid
WHERE r.rolname IN ('app_web','admin_datos')
ORDER BY r.rolname, m.rolname;

-- ----------------------------------------------------------------------------
-- 5. Verificar DEFAULT PRIVILEGES
-- ----------------------------------------------------------------------------
SELECT
    r.rolname AS rol_creador,
    d.defaclobjtype AS tipo_objeto,
    d.defaclacl AS privilegios_por_defecto
FROM pg_default_acl d
JOIN pg_roles r ON r.oid = d.defaclrole
WHERE d.defaclnamespace = 'public'::regnamespace
ORDER BY r.rolname, d.defaclobjtype;

-- ============================================================================
-- FIN verificar_permisos.sql
-- ============================================================================