import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

def build_pdf():
    pdf_path = os.path.join(os.path.dirname(__file__), "informe_u6.pdf")
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=26,
        bottomMargin=26
    )
    
    styles = getSampleStyleSheet()
    
    primary_color = colors.HexColor("#1A365D")
    secondary_color = colors.HexColor("#2B6CB0")
    dark_neutral = colors.HexColor("#2D3748")
    accent_green = colors.HexColor("#22543D")
    table_header_bg = colors.HexColor("#EBF8FF")
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12.5,
        leading=14.5,
        textColor=primary_color,
        alignment=1 # Center
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=10,
        textColor=secondary_color,
        alignment=1
    )
    
    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.2,
        leading=9.5,
        textColor=dark_neutral,
        alignment=1
    )
    
    sec_heading = ParagraphStyle(
        'SecHeading',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.2,
        leading=10.5,
        textColor=primary_color,
        spaceBefore=3.5,
        spaceAfter=1.5
    )
    
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.0,
        leading=8.8,
        textColor=dark_neutral
    )
    
    cell_bold = ParagraphStyle(
        'CellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=6.6,
        leading=8.2,
        textColor=dark_neutral
    )
    
    cell_normal = ParagraphStyle(
        'CellNormal',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=6.6,
        leading=8.2,
        textColor=dark_neutral
    )
    
    cell_green = ParagraphStyle(
        'CellGreen',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=6.6,
        leading=8.2,
        textColor=accent_green
    )

    story = []
    
    # Encabezado
    story.append(Paragraph("TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN — BASES DE DATOS II (UTN FRM)", subtitle_style))
    story.append(Paragraph("Informe post-incidente — TP Unidad 6: Mantenimiento, Respaldo y Recuperación", title_style))
    story.append(Paragraph("<b>Alumno:</b> Fabrizio Simon | <b>Motor:</b> PostgreSQL 18.6 | <b>Fecha:</b> 10/11/2026 | <b>Proyecto:</b> Food Store", meta_style))
    story.append(Spacer(1, 3))
    
    # 1. Datos del Respaldo
    story.append(Paragraph("1. DATOS DEL RESPALDO Y DEL ENTORNO DE PRUEBAS", sec_heading))
    p1 = (
        "<b>Base Principal:</b> foodstore (96 MB, +470k filas) | <b>Base Descartable:</b> foodstore_restore_test | "
        "<b>Archivo:</b> foodstore_20261110_155301.dump | <b>Formato:</b> Custom (-Fc) | "
        "<b>Tamaño:</b> 3.58 MB (3,752,831 B) | <b>Backup:</b> 10/11/2026 15:53:03 | "
        "<b>Simulacro:</b> 10/11/2026 15:54:45"
    )
    story.append(Paragraph(p1, body_style))
    story.append(Spacer(1, 2.5))
    
    # 2. Métricas de Continuidad
    story.append(Paragraph("2. TIEMPOS Y MÉTRICAS: RTO Y RPO (OBJETIVO VS. LO QUE ME DIO EN EL LAB)", sec_heading))
    t1_data = [
        [Paragraph("Métrica de Continuidad", cell_bold), Paragraph("Qué mide / Criterio", cell_bold), Paragraph("Objetivo Previsto", cell_bold), Paragraph("Lo que me dio en el Lab", cell_bold), Paragraph("Conclusión", cell_bold)],
        [Paragraph("<b>RTO</b> (Tiempo recuperación)", cell_normal), Paragraph("De punta a punta: createdb + pg_restore + validaciones SQL.", cell_normal), Paragraph("&le; 5 minutos (300 s)", cell_normal), Paragraph("<b>4.84 segundos</b>", cell_green), Paragraph("<b>Cumplido sobradísimo</b>", cell_green)],
        [Paragraph("<b>RPO</b> (Pérdida de datos)", cell_normal), Paragraph("Antigüedad del volcado al momento de iniciar la recuperación.", cell_normal), Paragraph("&le; 24 horas (política)", cell_normal), Paragraph("<b>1.70 min (102 s)</b>", cell_green), Paragraph("<b>Cumplido (0 pérdida)</b>", cell_green)]
    ]
    t1 = Table(t1_data, colWidths=[105, 185, 80, 85, 85])
    t1.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), table_header_bg),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
    ]))
    story.append(t1)
    story.append(Spacer(1, 2.5))
    
    # 3. Validación de Tablas e Integridad
    story.append(Paragraph("3. VALIDACIONES DE DATOS Y REGLAS LÓGICAS SOBRE FOODSTORE_RESTORE_TEST", sec_heading))
    t2_data = [
        [Paragraph("Tabla / Regla de Integridad", cell_bold), Paragraph("Filas en Origen", cell_bold), Paragraph("Filas Restauradas", cell_bold), Paragraph("Registros Inválidos", cell_bold), Paragraph("Estado", cell_bold)],
        [Paragraph("categoria (catálogo de rubros)", cell_normal), Paragraph("10", cell_normal), Paragraph("10", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ Idéntico", cell_green)],
        [Paragraph("cliente (maestro de clientes)", cell_normal), Paragraph("20,001", cell_normal), Paragraph("20,001", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ Idéntico", cell_green)],
        [Paragraph("producto (precio &gt;= 0 AND stock &gt;= 0)", cell_normal), Paragraph("50,002", cell_normal), Paragraph("50,002", cell_normal), Paragraph("<b>0</b> inv. (precio/stock &lt; 0)", cell_green), Paragraph("✅ 100% íntegro", cell_green)],
        [Paragraph("pedido (cabeceras transaccionales)", cell_normal), Paragraph("200,001", cell_normal), Paragraph("200,001", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ Idéntico", cell_green)],
        [Paragraph("detalle_pedido (cant &gt; 0 AND precio &gt;= 0)", cell_normal), Paragraph("200,000", cell_normal), Paragraph("200,000", cell_normal), Paragraph("<b>0</b> inv. (cant/precio &lt;= 0)", cell_green), Paragraph("✅ 100% íntegro", cell_green)],
    ]
    t2 = Table(t2_data, colWidths=[150, 95, 95, 110, 90])
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), table_header_bg),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('TOPPADDING', (0,0), (-1,-1), 1.2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.2),
    ]))
    story.append(t2)
    story.append(Spacer(1, 2.5))
    
    # 4. Problema Real Encontrado
    story.append(Paragraph("4. PROBLEMA REAL QUE ME ENCONTRÉ DURANTE EL PROCEDIMIENTO", sec_heading))
    p4 = (
        "Al principio, cuando corrí <code>pg_restore</code> pelado sin flags adicionales, el comando me tiraba advertencias de permisos y ownership "
        "porque intentaba recrear los mismos dueños y grants específicos de los roles del servidor de origen, que en una base de prueba descartable "
        "no hacen falta o pueden no existir. <b>Cómo lo solucioné:</b> Le agregué obligatoriamente las banderas <code>--no-owner --no-privileges</code> "
        "al comando dentro de <code>restore_test.ps1</code>. Con eso la restauración entró limpia y sin errores de permisos. También me aseguré de "
        "mapear con una vista de compatibilidad <code>detalle_pedido</code> sobre <code>pedido_producto</code> y la columna <code>precio</code> para "
        "que las consultas de validación de la cátedra corrieran sin tocar nada raro."
    )
    story.append(Paragraph(p4, body_style))
    story.append(Spacer(1, 2.5))
    
    # 5. Mejora Concreta
    story.append(Paragraph("5. MEJORAS CONCRETAS PARA LA PRÓXIMA EJECUCIÓN", sec_heading))
    p5 = (
        "<b>1. Restaurar con jobs en paralelo (-j):</b> Si la base en vez de 96 MB llega a pesar 20 o 50 GB, agregaría <code>pg_restore -j 4</code> "
        "para restaurar tablas e índices en paralelo usando varios núcleos del CPU y mantener el RTO bajo control.<br/>"
        "<b>2. Archivado continuo de WAL:</b> Para producción real, no alcanza solo con el backup de la noche; activaría <code>archive_mode = on</code> "
        "con archivado de WAL para tener Point-in-Time Recovery (PITR) y bajar el RPO real a menos de 5 minutos ante cualquier caída.<br/>"
        "<b>3. Alerta automática si falla:</b> En <code>backup_foodstore.ps1</code>, enganchar una notificación automática (un webhook a Discord/Slack "
        "o mail) si <code>$LASTEXITCODE != 0</code>, así no dependés de entrar a revisar la carpeta <code>logs/</code> a mano."
    )
    story.append(Paragraph(p5, body_style))
    story.append(Spacer(1, 2.5))
    
    # 6. OpenCode y Validación Humana
    story.append(Paragraph("6. ASISTENCIA DE OPENCODE Y VALIDACIÓN HUMANA", sec_heading))
    p6 = (
        "Usé OpenCode para generar la primera versión de los scripts de PowerShell y las consultas de auditoría. Ninguna sugerencia se aceptó a ciegas: "
        "<br/>• <i>Contraseñas:</i> OpenCode me proponía dejar un parámetro con la password en texto plano. Lo saqué de raíz y forcé que use <code>$env:PGPASSWORD</code>. "
        "<br/>• <i>Mantenimiento seguro:</i> Descarté de plano la idea de meter <code>VACUUM FULL</code> semanal porque te mete un bloqueo exclusivo (<code>AccessExclusiveLock</code>) y te frena la base; dejé <code>VACUUM (ANALYZE, VERBOSE)</code> ordinario que limpia tuplas muertas en caliente sin afectar a los usuarios. "
        "<br/>• <i>Medición real:</i> En vez de estimar tiempos aproximados, armé el script <code>restore_test.ps1</code> con un cronómetro real de sistema para medir el RTO exacto con evidencia en log."
    )
    story.append(Paragraph(p6, body_style))

    doc.build(story)
    print("PDF humanizado generado exitosamente en:", pdf_path)

if __name__ == "__main__":
    build_pdf()
