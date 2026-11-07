# TP Unidad 4 — Parte 1: FNBC sobre ControlLoteAlmacen

## Esquema original

```sql
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);
```

## Dependencias funcionales

- FD1: `{LoteID, DepositoID} → ResponsableControlID` (clave primaria)
- FD2: `ResponsableControlID → DepositoID` (cada responsable pertenece a un único depósito)

## Claves candidatas

- Clave candidata única: `{LoteID, DepositoID}`
- Atributos primos: LoteID, DepositoID
- Atributos no primos: ResponsableControlID

## ¿Cumple FNBC?

**No.** La dependencia violatoria es `ResponsableControlID → DepositoID`, porque `ResponsableControlID` no es superclave.

## Descomposición sin pérdida

- `R1(ResponsableControlID, DepositoID)` — PK: ResponsableControlID
- `R2(LoteID, DepositoID, ResponsableControlID)` — PK: (LoteID, DepositoID), FK: ResponsableControlID → R1

## Anomalías detectadas

- **Inserción:** No se puede registrar un responsable sin un lote asociado.
- **Borrado:** Al borrar la última fila de un responsable, se pierde su dato maestro de depósito.
- **Actualización:** Un cambio de depósito de un responsable requiere actualizar múltiples filas.
