# AGENTS.md

## Project

PostgreSQL 17 + DBeaver 26.2.0 - Windows 11.
Single database project: `food_store_dev`.

## Key Constraints

- **Never work on `food_store_dev` directly.** All changes must be tested on `food_store_copia` first.
- **Always use transactions in DBeaver.** Set Auto → Manual, run scripts inside `BEGIN; ... ROLLBACK;` (inspect), then `COMMIT;` if correct.
- **Backup before ALTER/DROP.** Right-click `food_store_copia` → Herramientas → Backup → save to `backups\backup_YYYYMMDD.dump`.

## Environment

- OS: Windows 11
- Database: PostgreSQL 17
- Client: DBeaver 26.2.0
- Working directory: `C:\Users\Fabri\OneDrive\Documentos\Default Project`

## Workflow

1. Create `food_store_copia` from `food_store_dev`: `CREATE DATABASE food_store_copia WITH TEMPLATE food_store_dev;`
2. If "accessed by other users" error: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='food_store_dev';` then retry.
3. Close all editors on `food_store_dev` before copying.
