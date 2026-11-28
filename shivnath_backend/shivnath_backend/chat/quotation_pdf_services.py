import io
import re
from datetime import datetime


def generate_pure_quotation_pdf(quotation):
    """
    Constructs an authoritative, standards-compliant vector PDF binary (PDF-1.4)
    for formal quotations without external dependencies (pure Python standard library).
    """
    def clean(s):
        if not s:
            return ""
        s = str(s).replace('(', '\\(').replace(')', '\\)').replace('\\', '\\\\')
        return re.sub(r'[^\x20-\x7E]', ' ', s).strip()

    def wrap_lines(text, max_len=65):
        if not text:
            return []
        words = text.split()
        lines = []
        current = []
        curr_len = 0
        for w in words:
            if curr_len + len(w) + (1 if current else 0) <= max_len:
                current.append(w)
                curr_len += len(w) + (1 if len(current) > 1 else 0)
            else:
                if current:
                    lines.append(' '.join(current))
                current = [w]
                curr_len = len(w)
        if current:
            lines.append(' '.join(current))
        return lines

    company_name = "SHIVNATH AGENCIES"
    company_address = "Ekta Nagar, Pragati Nagar, LIC Colony, Near Mowa Thana, Raipur, Chhattisgarh"
    company_gstin = "22AQNPK7620D1Z3"
    company_phone = "9826421818"
    company_email = "support@waterwala.in"

    q_number = quotation.quotation_number or f"Q-FRN-2026-{quotation.id:04d}"
    q_date = quotation.created_at.strftime('%d-%b-%Y') if quotation.created_at else datetime.now().strftime('%d-%b-%Y')
    q_status = (quotation.status or "PUBLISHED").upper()
    q_validity = quotation.validity or "Valid for 30 days from issuance"

    target_desc = "All Network Franchises & Key Accounts"
    if quotation.franchise:
        target_desc = quotation.franchise.business_name
        if getattr(quotation.franchise, 'city', None):
            target_desc += f", {quotation.franchise.city}"

    prod_name = quotation.product.name if quotation.product else quotation.title
    prod_sku = getattr(quotation.product, 'sku', '') if quotation.product else ''
    prod_size = getattr(quotation.product, 'size', '') if quotation.product else ''

    unit_rate = float(quotation.unit_price or 0.0)
    total_val = float(quotation.total_price or 0.0)
    discount_pct = float(quotation.discount_percent or 0.0)
    add_charges = float(quotation.additional_charges or 0.0)
    final_val = float(quotation.final_amount or total_val)

    stream_lines = []

    # Header Accent Box (Brand Blue)
    stream_lines.append("0.05 0.5 0.8 rg")
    stream_lines.append("30 755 535 55 re f")

    # Header Text
    stream_lines.append("1 1 1 rg")  # White
    stream_lines.append(f"BT /F1 18 Tf 45 788 Td ({clean(company_name)}) Tj ET")
    stream_lines.append("BT /F1 9 Tf 45 776 Td (WATER WALA - COMMERCIAL PRICING PROPOSAL & B2B QUOTATION) Tj ET")
    stream_lines.append("BT /F1 11 Tf 45 762 Td (OFFICIAL COMMERCIAL QUOTATION) Tj ET")

    # Company Details (Left)
    stream_lines.append("0 0 0 rg")  # Black
    stream_lines.append(f"BT /F1 8 Tf 40 738 Td (Issuing Entity: {clean(company_name)}) Tj ET")
    addr_lines = wrap_lines(company_address, max_len=45)
    s_y = 726
    for al in addr_lines[:2]:
        stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td ({clean(al)}) Tj ET")
        s_y -= 11
    stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td (GSTIN: {clean(company_gstin)} | Helpline: {clean(company_phone)}) Tj ET")

    # Quotation Metadata (Right)
    stream_lines.append(f"BT /F1 9 Tf 350 738 Td (Quotation Ref: {clean(q_number)}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 726 Td (Issued Date: {clean(q_date)}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 714 Td (Validity: {clean(q_validity[:32])}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 702 Td (Proposal Status: {clean(q_status)}) Tj ET")

    # Horizontal Divider
    stream_lines.append("0.7 0.7 0.7 RG 1 w 30 684 m 565 684 l S")

    # Target / Recipient Banner
    stream_lines.append("0.95 0.97 1.0 rg")
    stream_lines.append("30 648 535 28 re f")
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 9 Tf 40 663 Td (Quotation Prepared For: {clean(target_desc[:65])}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 40 652 Td (Quotation Subject / Title: {clean(quotation.title[:70])}) Tj ET")

    # Pricing Table Header
    y_table = 618
    stream_lines.append("0.9 0.94 0.98 rg")
    stream_lines.append(f"30 {y_table} 535 20 re f")
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 8 Tf 35 {y_table + 6} Td (#  Product / Service Description) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 260 {y_table + 6} Td (Package / Size) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 340 {y_table + 6} Td (Tier / Volume) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 420 {y_table + 6} Td (Rate \\(INR\\)) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 490 {y_table + 6} Td (Total \\(INR\\)) Tj ET")

    # Item Row
    y_row = y_table - 16
    stream_lines.append(f"BT /F1 9 Tf 35 {y_row} Td (1  {clean(prod_name[:36])}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 260 {y_row} Td ({clean(prod_size or prod_sku or 'Standard')}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 340 {y_row} Td ({clean(quotation.quantity_tier or '1 Unit')}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 420 {y_row} Td ({unit_rate:.2f}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 490 {y_row} Td ({total_val:.2f}) Tj ET")

    # Line below row
    stream_lines.append(f"0.85 0.85 0.85 RG 0.5 w 30 {y_row - 6} m 565 {y_row - 6} l S")

    # Summary Financials Box
    y_fin = y_row - 22
    stream_lines.append(f"BT /F1 8 Tf 350 {y_fin} Td (Base Quoted Price:) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 490 {y_fin} Td (INR {total_val:.2f}) Tj ET")
    y_fin -= 14

    if discount_pct > 0:
        disc_val = total_val * (discount_pct / 100.0)
        stream_lines.append(f"BT /F1 8 Tf 350 {y_fin} Td (Volume Discount \\({discount_pct:.1f}%\\):) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 490 {y_fin} Td (-INR {disc_val:.2f}) Tj ET")
        y_fin -= 14

    if add_charges > 0:
        stream_lines.append(f"BT /F1 8 Tf 350 {y_fin} Td (Logistics / Packaging Charges:) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 490 {y_fin} Td (+INR {add_charges:.2f}) Tj ET")
        y_fin -= 14

    # Total Highlight Bar
    stream_lines.append("0.05 0.5 0.8 rg")
    stream_lines.append(f"340 {y_fin - 4} 225 20 re f")
    stream_lines.append("1 1 1 rg")
    stream_lines.append(f"BT /F1 9 Tf 350 {y_fin + 2} Td (FINAL CONTRACT AMOUNT:) Tj ET")
    stream_lines.append(f"BT /F1 10 Tf 480 {y_fin + 2} Td (INR {final_val:.2f}) Tj ET")

    # Terms and Conditions Box
    y_terms = y_fin - 35
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 9 Tf 35 {y_terms} Td (TERMS, CONDITIONS & SPECIFICATIONS:) Tj ET")
    y_terms -= 14

    terms_text = quotation.applicable_terms or "1. All packaged drinking water complies with BIS IS 14543 certification standards. 2. Rates are applicable for the mentioned volume tier. 3. GST, delivery schedules, and returnable jar deposits handled as per formal agreement."
    terms_lines = wrap_lines(terms_text, max_len=90)
    for tl in terms_lines[:6]:
        stream_lines.append(f"BT /F1 8 Tf 35 {y_terms} Td ({clean(tl)}) Tj ET")
        y_terms -= 11

    if quotation.notes:
        y_terms -= 6
        stream_lines.append(f"BT /F1 8 Tf 35 {y_terms} Td (Special Executive Notes: {clean(quotation.notes[:85])}) Tj ET")
        y_terms -= 11

    # Authorized Signature / Footer
    stream_lines.append("0.8 0.8 0.8 RG 1 w 30 110 m 565 110 l S")
    stream_lines.append("0 0 0 rg")
    stream_lines.append("BT /F1 8 Tf 40 90 Td (Issued By: Commercial Sales Division) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 40 78 Td ({clean(company_name)} - Raipur Dispatch Plant) Tj ET")

    stream_lines.append("BT /F1 8 Tf 380 90 Td (Authorized Signatory / Digital Seal) Tj ET")
    stream_lines.append(f"BT /F1 7 Tf 380 78 Td (Digitally Verified & Approved on {clean(q_date)}) Tj ET")

    stream_lines.append(f"BT /F1 7 Tf 170 40 Td (Official Proposal Ref #{clean(q_number)} - Powered by Water Wala Ecosystem) Tj ET")

    content_stream = "\n".join(stream_lines).encode('latin-1', 'replace')

    # Standard PDF-1.4 Objects
    objects = []
    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    objects.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
    objects.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>")
    objects.append(b"<< /Length " + str(len(content_stream)).encode('ascii') + b" >>\nstream\n" + content_stream + b"\nendstream")
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    pdf_out = io.BytesIO()
    pdf_out.write(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")

    xref_offsets = [0]
    for obj_idx, obj_data in enumerate(objects, 1):
        xref_offsets.append(pdf_out.tell())
        pdf_out.write(f"{obj_idx} 0 obj\n".encode('ascii'))
        pdf_out.write(obj_data)
        pdf_out.write(b"\nendobj\n")

    start_xref = pdf_out.tell()
    pdf_out.write(b"xref\n")
    pdf_out.write(f"0 {len(objects) + 1}\n".encode('ascii'))
    pdf_out.write(b"0000000000 65535 f \n")
    for off in xref_offsets[1:]:
        pdf_out.write(f"{off:010d} 00000 n \n".encode('ascii'))

    pdf_out.write(b"trailer\n")
    pdf_out.write(f"<< /Size {len(objects) + 1} /Root 1 0 R >>\n".encode('ascii'))
    pdf_out.write(b"startxref\n")
    pdf_out.write(f"{start_xref}\n".encode('ascii'))
    pdf_out.write(b"%%EOF\n")

    return pdf_out.getvalue()
