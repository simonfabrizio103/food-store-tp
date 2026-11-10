"""
TP Unidad 5 - Parte C: anonimizador del log de auditoria.

Toma un archivo de log de PostgreSQL y produce una version anonimizada:
  - Emails -> usuario_anon@example.com
  - Contrasenas y argumentos sensibles de fn_autenticar -> ***
  - Host/puerto de origen -> host=localhost port=NNNNN
  - Nombres de usuario de base de datos: se conservan (son roles, no personas)

Uso:
    python anonimizar_log.py <log_entrada> <log_salida> [--desde "HH:MM:SS"] [--hasta "HH:MM:SS"]
"""
import re
import sys


def decode_line(raw: bytes) -> str:
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252")


PORT_RE = re.compile(r"port=\d+")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
FN_AUTH_RE = re.compile(
    r"fn_autenticar\(\s*'[^']*'\s*,\s*'[^']*'\s*\)", re.IGNORECASE
)
PASSWORD_FN_RE = re.compile(
    r"fn_resetear_password\(\s*'[^']*'\s*,\s*'[^']*'\s*\)", re.IGNORECASE
)
# CREATE ROLE x LOGIN PASSWORD '...' -> redactar la clave
CREATE_PW_RE = re.compile(
    r"(CREATE\s+ROLE\s+\S+.*?PASSWORD\s+)'[^']*'", re.IGNORECASE
)


def anonymize(text: str) -> str:
    text = FN_AUTH_RE.sub("fn_autenticar('usuario_anon@example.com', '***')", text)
    text = PASSWORD_FN_RE.sub(
        "fn_resetear_password('usuario_anon@example.com', '***')", text
    )
    text = CREATE_PW_RE.sub(r"\1'***'", text)
    text = EMAIL_RE.sub("usuario_anon@example.com", text)
    text = PORT_RE.sub("port=NNNNN", text)
    text = text.replace("host=::1", "host=localhost")
    text = text.replace("host=127.0.0.1", "host=localhost")
    return text


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    desde = hasta = None
    if "--desde" in sys.argv:
        desde = sys.argv[sys.argv.index("--desde") + 1]
    if "--hasta" in sys.argv:
        hasta = sys.argv[sys.argv.index("--hasta") + 1]
    match = []
    with open(src, "rb") as f:
        raw = f.read().split(b"\n")
    keep = False
    for b in raw:
        s = decode_line(b).rstrip("\r")
        m = re.match(r"^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})", s)
        if m:
            hora = m.group(2)
            if desde and hasta:
                keep = desde <= hora <= hasta
            elif desde:
                keep = hora >= desde
            elif hasta:
                keep = hora <= hasta
            else:
                keep = True
        if keep:
            match.append(anonymize(s))
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(match) + "\n")
    print(f"Lineas anonimizadas: {len(match)} -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
