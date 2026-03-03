from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.platypus import Table, TableStyle
from reportlab.lib.units import cm
from datetime import datetime
import os

# Importe für das Ausfüllen der AcroForm (Stundenzettel)
from pypdf import PdfReader, PdfWriter
from pypdf.errors import PyPdfError

# WICHTIG: Funktionsname muss zur main.py passen!
def create_performance_pdf(data, output_path):
    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4
    
    meta = data['meta']
    lines = data['lines']
    
    # --- 1. HEADER ---
    # Links: Firmenname / Adresse
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(2.0*cm, height - 2.0*cm, "CheckX Prüfservice GmbH")
    
    c.setFont("Helvetica", 9)
    c.drawString(2.0*cm, height - 2.5*cm, "Schillerstr. 2")
    c.drawString(2.0*cm, height - 2.9*cm, "74889 Sinsheim")
    c.drawString(2.0*cm, height - 3.3*cm, "+49 171-9999710")
    
    # Rechts: Titel & Jahr
    c.setFont("Helvetica-Bold", 20)
    c.drawRightString(width - 2.0*cm, height - 2.0*cm, "Montagebericht")
    c.setFont("Helvetica", 12)
    c.drawRightString(width - 2.0*cm, height - 2.6*cm, "Prüfservice")
    c.drawRightString(width - 2.0*cm, height - 3.2*cm, str(datetime.now().year))

    # --- 2. ADRESS-KÄSTEN ---
    y_box_top = height - 5.0*cm
    box_height = 3.0*cm
    box_width = 8.0*cm
    
    # Kasten Links: Auftraggeber
    c.setLineWidth(0.5)
    c.rect(2.0*cm, y_box_top - box_height, box_width, box_height)
    
    c.setFont("Helvetica-Bold", 8)
    c.drawString(2.2*cm, y_box_top - 0.4*cm, "Auftraggeber")
    
    c.setFont("Helvetica", 10)
    # Sicherer Zugriff auf Dictionary mit .get(), falls Felder leer sind
    c.drawString(2.2*cm, y_box_top - 1.0*cm, str(meta.get('company_name', '')))
    c.drawString(2.2*cm, y_box_top - 1.5*cm, f"{meta.get('street', '')} {meta.get('house_number', '')}")
    c.drawString(2.2*cm, y_box_top - 2.0*cm, f"{meta.get('zip_code', '')} {meta.get('city', '')}")

    # Kasten Rechts: Prüfort
    c.rect(11.0*cm, y_box_top - box_height, box_width, box_height)
    
    c.setFont("Helvetica-Bold", 8)
    c.drawString(11.2*cm, y_box_top - 0.4*cm, "Prüfort: Werk / Standort")
    
    c.setFont("Helvetica", 10)
    c.drawString(11.2*cm, y_box_top - 1.0*cm, str(meta.get('company_name', '')))
    c.drawString(11.2*cm, y_box_top - 1.5*cm, str(meta.get('city', ''))) 

    # --- 3. INFOS ---
    y_info = y_box_top - box_height - 1.0*cm
    
    # Labels
    c.setFont("Helvetica-Bold", 9)
    c.drawString(2.0*cm, y_info, "Prüftechniker:")
    c.drawString(2.0*cm, y_info - 0.5*cm, "Ansprechpartner (CheckX):")
    
    c.drawString(11.0*cm, y_info, "Datum:")
    c.drawString(11.0*cm, y_info - 0.5*cm, "KW:")
    c.drawString(11.0*cm, y_info - 1.0*cm, "Ansprechpartner (Kunde):")

    # Werte
    c.setFont("Helvetica", 9)
    tech_name = f"{meta.get('first_name', '')} {meta.get('last_name', '')}"
    c.drawString(6.0*cm, y_info, tech_name)
    c.drawString(6.0*cm, y_info - 0.5*cm, tech_name) 
    
    # Datum & KW
    date_val = meta.get('date_entry', '')
    date_str = str(date_val)
    kw_str = ""
    try:
        # Falls es ein String ist
        if isinstance(date_val, str):
            dt = datetime.strptime(date_val, "%Y-%m-%d")
        else:
            dt = date_val # Falls es schon ein date-Objekt ist
            
        date_str = dt.strftime("%d.%m.%Y")
        kw_str = str(dt.isocalendar()[1])
    except:
        pass
        
    c.drawString(15.5*cm, y_info, date_str)
    c.drawString(15.5*cm, y_info - 0.5*cm, kw_str)
    
    # Kontaktperson
    cp_name = f"{meta.get('cp1_firstname', '')} {meta.get('cp1_lastname', '')}".strip()
    if not cp_name: cp_name = "-"
    c.drawString(15.5*cm, y_info - 1.0*cm, cp_name)

    # --- 4. TABELLE ---
    # Header Zeile
    table_data = [["Pos", "Bezeichnung", "Menge\n(Soll)", "Rest", "Stück\n(Heute)"]]
    
    # Zeilen füllen
    for item in lines:
        # "Eventual" anzeigen, wenn Soll = 0
        soll_text = str(item['target']) if item['target'] > 0 else "Eventual"
        
        table_data.append([
            str(item['pos']),
            item['name'],
            soll_text,
            str(item['rest']),
            str(item['current'])
        ])
    
    # Tabelle erstellen
    col_widths = [1.5*cm, 9.0*cm, 2.0*cm, 2.0*cm, 2.0*cm]
    t = Table(table_data, colWidths=col_widths)
    
    # Style
    style = TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
        ('TEXTCOLOR', (0,0), (-1,0), colors.black),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('ALIGN', (2,0), (-1,-1), 'CENTER'),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,0), 9),
        ('FONTNAME', (0,1), (-1,-1), 'Helvetica'),
        ('FONTSIZE', (0,1), (-1,-1), 9),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.black),
    ])
    t.setStyle(style)
    
    # Tabelle platzieren
    w, h = t.wrap(width, height)
    t.drawOn(c, 2.0*cm, y_info - 2.0*cm - h)
    
    # --- 5. UNTERSCHRIFTEN ---
    y_sig = 4.0*cm
    
    c.setLineWidth(1)
    c.line(2.0*cm, y_sig, 9.0*cm, y_sig)
    c.setFont("Helvetica", 8)
    c.drawString(2.0*cm, y_sig - 0.5*cm, "Unterschrift Techniker")
    
    c.line(11.0*cm, y_sig, 18.0*cm, y_sig)
    c.drawString(11.0*cm, y_sig - 0.5*cm, "Unterschrift Auftraggeber")
    
    c.save()
    return output_path


# =========================================================
# ACROFORM-PDF GENERATOR (Stundenzettel)
# =========================================================
def generate_timesheet_acroform(emp_name: str, emp_id: str, year: int, month: int, entries: list, template_path: str, output_path: str):
    """
    Nimmt die Vorlage, füllt die AcroForm-Felder aus und speichert sie ab.
    """
    reader = PdfReader(template_path)
    writer = PdfWriter()

    # .append() kopiert die komplette PDF-Struktur INKLUSIVE der ausfüllbaren Felder!
    writer.append(reader)

    # NEU: Monatsnamen auf Deutsch übersetzen
    monate = ["", "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    monat_string = monate[month]

    # Wir bauen ein Dictionary mit allen Daten für die PDF-Felder
    form_data = {
        "feld_name": emp_name,
        "feld_personalnummer": emp_id,
        "feld_monat": f"{monat_string} {year}" # Ergibt z.B. "März 2026"
    }

    # Wir durchlaufen die Datenbank-Einträge dieses Monats
    for entry in entries:
        date_val = entry.get('date')
        if not date_val:
            continue
            
        # 1. Tag extrahieren
        if isinstance(date_val, str):
            day = int(date_val.split('-')[2])
            # Optional: Mach das Datum hübsch für die PDF (DD.MM.YYYY)
            parts = date_val.split('-')
            form_data[f"datum_{day}"] = f"{parts[2]}.{parts[1]}.{parts[0]}"
        else:
            day = date_val.day
            form_data[f"datum_{day}"] = date_val.strftime("%d.%m.%Y")
            
        # 2. Projekt
        form_data[f"projekt_{day}"] = entry.get('project', '')
        
        # 3. Startzeit formatieren (mit "Uhr")
        start_dt = entry.get('start_time')
        if start_dt and hasattr(start_dt, 'strftime'):
            form_data[f"start_{day}"] = start_dt.strftime('%H:%M Uhr')
            
        # 4. Endzeit formatieren (mit "Uhr")
        end_dt = entry.get('end_time')
        if end_dt and hasattr(end_dt, 'strftime'):
            form_data[f"ende_{day}"] = end_dt.strftime('%H:%M Uhr')
            
        # 5. Pause (mit "Min.")
        break_mins = entry.get('break_minutes')
        if break_mins is not None:
            form_data[f"pause_{day}"] = f"{int(break_mins)} Min."
            
        # 6. Dauer in HH:MM formatieren (mit "Std.")
        duration = entry.get('duration_minutes')
        if duration is not None:
            h = int(duration // 60)
            m = int(duration % 60)
            form_data[f"dauer_{day}"] = f"{h:02d}:{m:02d} Std."

    # Schreibe die Daten in die AcroForm (sofern welche existieren)
    if "/AcroForm" in writer.root_object:
        writer.update_page_form_field_values(writer.pages[0], form_data)
    else:
        print("WARNUNG: Die hochgeladene PDF-Vorlage enthält keine interaktiven Formularfelder!")

    # Speichere die fertige PDF
    with open(output_path, "wb") as output_stream:
        writer.write(output_stream)