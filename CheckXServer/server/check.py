from pypdf import PdfReader

try:
    reader = PdfReader("pdf_templates/timesheet.pdf")
    fields = reader.get_fields()
    
    print("\n--- GEFUNDENE FORMULARFELDER IN DEINER PDF ---")
    if fields:
        for field_name in fields.keys():
            print(f"Gefunden: '{field_name}'")
    else:
        print("Keine interaktiven Felder gefunden!")
    print("----------------------------------------------\n")
except FileNotFoundError:
    print("Fehler: Konnte pdf_templates/timesheet.pdf nicht finden.")