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
        topMargin=30,
        bottomMargin=30
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
        fontSize=13,
        leading=15,
        textColor=primary_color,
        alignment=1 # Center
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=secondary_color,
        alignment=1
    )
    
    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=10,
        textColor=dark_neutral,
        alignment=1
    )
    
    sec_heading = ParagraphStyle(
        'SecHeading',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=primary_color,
        spaceBefore=4,
        spaceAfter=2
    )
    
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.2,
        leading=9.2,
        textColor=dark_neutral
    )
    
    cell_bold = ParagraphStyle(
        'CellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=6.8,
        leading=8.5,
        textColor=dark_neutral
    )
    
    cell_normal = ParagraphStyle(
        'CellNormal',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=6.8,
        leading=8.5,
        textColor=dark_neutral
    )
    
    cell_green = ParagraphStyle(
        'CellGreen',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=6.8,
        leading=8.5,
        textColor=accent_green
    )

    story = []
    
    # Encabezado
    story.append(Paragraph("TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN — BASES DE DATOS II (UTN FRM)", subtitle_style))
    story.append(Paragraph("Trabajo Práctico — Unidad 6: Mantenimiento, Respaldo y Recuperación", title_style))
    story.append(Paragraph("<b>Proyecto Integrador:</b> Food Store | <b>Motor:</b> PostgreSQL 18.6 | <b>Alumno:</b> Fabrizio Simon | <b>Fecha:</b> 10/11/2026", meta_style))
    story.append(Spacer(1, 4))
    
    # 1. Datos Generales del Respaldo
    story.append(Paragraph("1. DATOS GENERALES DEL RESPALDO Y ENTORNO", sec_heading))
    p1 = (
        "<b>Base Principal:</b> foodstore (96 MB) | <b>Base Descartable:</b> foodstore_restore_test | "
        "<b>Archivo:</b> foodstore_20261110_155301.dump | <b>Formato:</b> Custom (-Fc) | "
        "<b>Tamaño:</b> 3.58 MB (3,752,831 B) | <b>Timestamp Backup:</b> 2026-11-10 15:53:03 | "
        "<b>Timestamp Simulacro:</b> 2026-11-10 15:54:45"
    )
    story.append(Paragraph(p1, body_style))
    story.append(Spacer(1, 3))
    
    # 2. Métricas de Continuidad
    story.append(Paragraph("2. MÉTRICAS DE RESILIENCIA Y RECUPERACIÓN: RPO Y RTO", sec_heading))
    t1_data = [
        [Paragraph("Métrica", cell_bold), Paragraph("Definición Operacional", cell_bold), Paragraph("Objetivo Previsto", cell_bold), Paragraph("Valor Observado", cell_bold), Paragraph("Veredicto", cell_bold)],
        [Paragraph("<b>RTO</b> (Recovery Time Obj.)", cell_normal), Paragraph("Tiempo total desde inicio de recreación hasta validación completa.", cell_normal), Paragraph("&le; 5 minutos (300 s)", cell_normal), Paragraph("<b>4.84 segundos</b>", cell_green), Paragraph("<b>CUMPLIDO</b> (&lt; 2%)", cell_green)],
        [Paragraph("<b>RPO</b> (Recovery Point Obj.)", cell_normal), Paragraph("Antigüedad del respaldo / máxima pérdida tolerable de datos.", cell_normal), Paragraph("&le; 24 horas (política)", cell_normal), Paragraph("<b>1.70 min (102 s)</b>", cell_green), Paragraph("<b>CUMPLIDO</b> (0 pérdida)", cell_green)]
    ]
    t1 = Table(t1_data, colWidths=[100, 190, 85, 85, 80])
    t1.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), table_header_bg),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ]))
    story.append(t1)
    story.append(Spacer(1, 3))
    
    # 3. Validación de Tablas e Integridad
    story.append(Paragraph("3. VALIDACIÓN POST-RESTAURACIÓN (INTEGRIDAD REFERENCIAL Y REGLAS LÓGICAS)", sec_heading))
    t2_data = [
        [Paragraph("Tabla / Restricción Evaluada", cell_bold), Paragraph("Filas Origen", cell_bold), Paragraph("Filas Restauradas", cell_bold), Paragraph("Registros Inválidos", cell_bold), Paragraph("Veredicto", cell_bold)],
        [Paragraph("categoria (catálogo)", cell_normal), Paragraph("10", cell_normal), Paragraph("10", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ 100% Coincidente", cell_green)],
        [Paragraph("cliente (maestro clientes)", cell_normal), Paragraph("20,001", cell_normal), Paragraph("20,001", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ 100% Coincidente", cell_green)],
        [Paragraph("producto (precio &gt;= 0, stock &gt;= 0)", cell_normal), Paragraph("50,002", cell_normal), Paragraph("50,002", cell_normal), Paragraph("0 inv. (precio/stock &lt; 0)", cell_green), Paragraph("✅ 100% Coincidente", cell_green)],
        [Paragraph("pedido (cabeceras transaccionales)", cell_normal), Paragraph("200,001", cell_normal), Paragraph("200,001", cell_normal), Paragraph("0", cell_normal), Paragraph("✅ 100% Coincidente", cell_green)],
        [Paragraph("detalle_pedido (cant &gt; 0, precio &gt;= 0)", cell_normal), Paragraph("200,000", cell_normal), Paragraph("200,000", cell_normal), Paragraph("0 inv. (cant/precio &lt;= 0)", cell_green), Paragraph("✅ 100% Coincidente", cell_green)],
    ]
    t2 = Table(t2_data, colWidths=[150, 95, 95, 110, 90])
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), table_header_bg),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E0")),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
    ]))
    story.append(t2)
    story.append(Spacer(1, 3))
    
    # 4. Problema Real Encontrado
    story.append(Paragraph("4. PROBLEMA REAL ENCONTRADO DURANTE EL PROCEDIMIENTO", sec_heading))
    p4 = (
        "<b>Incompatibilidad de propietarios y privilegios en entornos descartables:</b> Al ejecutar <code>pg_restore</code> de forma inicial sin "
        "modificadores, el motor intentó asignar permisos y ownership a roles específicos del servidor de origen, provocando advertencias y bloqueos "
        "de restauración. <i>Solución aplicada:</i> Se incorporaron de manera obligatoria las banderas <code>--no-owner</code> y <code>--no-privileges</code> "
        "en <code>restore_test.ps1</code>, asegurando que la base descartable <code>foodstore_restore_test</code> se restaure limpiamente bajo el rol de conexión local."
    )
    story.append(Paragraph(p4, body_style))
    story.append(Spacer(1, 3))
    
    # 5. Mejora Concreta
    story.append(Paragraph("5. MEJORA CONCRETA PARA LA SIGUIENTE EJECUCIÓN", sec_heading))
    p5 = (
        "<b>1. Restauración en Paralelo (-j jobs):</b> Implementar <code>pg_restore -j 4</code> para paralelizar la reconstrucción de índices "
        "y tablas sobre procesadores multinúcleo, lo cual optimizará el RTO ante escenarios con volúmenes superiores a 20 GB.<br/>"
        "<b>2. Archivación Continua WAL (PITR):</b> Configurar <code>archive_mode = on</code> y archivado periódico de segmentos WAL para posibilitar "
        "Point-in-Time Recovery, reduciendo el RPO a ventana cercana a cero (menor a 5 minutos) sin depender únicamente del dump diario."
    )
    story.append(Paragraph(p5, body_style))
    story.append(Spacer(1, 3))
    
    # 6. OpenCode y Validación Humana
    story.append(Paragraph("6. ASISTENCIA ASISTIDA CON OPENCODE Y VALIDACIÓN HUMANA", sec_heading))
    p6 = (
        "OpenCode asistió en la redacción preliminar de los scripts PowerShell y consultas de monitoreo. <b>Validaciones y correcciones humanas críticas:</b> "
        "<br/>• <i>Seguridad de credenciales:</i> Se eliminaron contraseñas en código duro sugeridas en borradores, requiriendo <code>$env:PGPASSWORD</code>. "
        "<br/>• <i>Mantenimiento no bloqueante:</i> Se rechazó el uso de <code>VACUUM FULL</code> por su bloqueo <code>AccessExclusiveLock</code>; se reemplazó por <code>VACUUM (ANALYZE, VERBOSE)</code>. "
        "<br/>• <i>Cronometraje real:</i> Se estructuró <code>restore_test.ps1</code> con <code>[System.Diagnostics.Stopwatch]</code> para auditar empíricamente el RTO y RPO."
    )
    story.append(Paragraph(p6, body_style))

    doc.build(story)
    print("PDF generado exitosamente en:", pdf_path)

if __name__ == "__main__":
    build_pdf()
