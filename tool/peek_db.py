"""Read the full Overview & Data Dictionary sheet."""
import openpyxl

wb = openpyxl.load_workbook(r"c:\Users\Ayaan\Downloads\Video\Football\Football_Database_Expanded.xlsx", read_only=True, data_only=True)
ws = wb['Overview & Data Dictionary']

for i, row in enumerate(ws.iter_rows(values_only=True)):
    vals = [v for v in row if v is not None]
    if vals:
        print(f"  Row {i}: {list(row)}")

wb.close()
