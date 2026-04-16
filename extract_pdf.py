import pdfplumber
import sys
import io

pdf_path = r"C:\Users\henry\Desktop\Claude Website\Heat trasnfer AME 431\AME 431 - Final Project.pdf"
out_path = r"C:\Users\henry\Desktop\Claude Website\pdf_extract_output.txt"

out = io.open(out_path, "w", encoding="utf-8")

def w(s=""):
    out.write(s + "\n")

try:
    with pdfplumber.open(pdf_path) as pdf:
        total_pages = len(pdf.pages)
        w(f"=== TOTAL PAGES: {total_pages} ===")
        w()

        for i, page in enumerate(pdf.pages):
            w()
            w("="*60)
            w(f"PAGE {i+1} of {total_pages}")
            w("="*60)

            # Extract text
            text = page.extract_text(x_tolerance=3, y_tolerance=3)
            if text:
                w(text)
            else:
                w("[NO TEXT EXTRACTED ON THIS PAGE]")

            # Extract tables
            tables = page.extract_tables()
            if tables:
                w(f"\n--- TABLES ON PAGE {i+1} ---")
                for t_idx, table in enumerate(tables):
                    w(f"\nTable {t_idx+1}:")
                    for row in table:
                        if row:
                            w(" | ".join([str(cell) if cell else "" for cell in row]))

    w()
    w("=== EXTRACTION COMPLETE (pdfplumber) ===")

except Exception as e:
    w(f"pdfplumber failed: {e}")
    w("Falling back to pypdf...")

    from pypdf import PdfReader
    reader = PdfReader(pdf_path)
    total_pages = len(reader.pages)
    w(f"=== TOTAL PAGES: {total_pages} ===")
    w()

    for i, page in enumerate(reader.pages):
        w()
        w("="*60)
        w(f"PAGE {i+1} of {total_pages}")
        w("="*60)
        text = page.extract_text()
        if text:
            w(text)
        else:
            w("[NO TEXT EXTRACTED ON THIS PAGE]")

    w()
    w("=== EXTRACTION COMPLETE (pypdf fallback) ===")

finally:
    out.close()

print(f"Done. Output written to: {out_path}")
