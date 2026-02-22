#!/usr/bin/env python3
import os
import json
import csv
from datetime import datetime

# =========================
# CONFIG – EDIT THESE ONCE
# =========================
BASE_DIR = os.path.expanduser("~/garage/.business")
OUTGOING_DIR = os.path.expanduser("~/garage/Outgoing")

INVOICE_STATE_JSON = os.path.join(BASE_DIR, "invoices.json")
INVOICE_CSV_DIR = os.path.join(BASE_DIR, "invoices")
INVOICE_CSV_PATH = os.path.join(INVOICE_CSV_DIR, "invoices.csv")

# Business identity (hard-coded so you don't type it every time)
BUSINESS_NAME = "Good 'Nuff Mobile Mechanic"
BUSINESS_OWNER = "Jeremiah Jervis"
BUSINESS_PHONE = "555-555-5555"      # <-- put your real number
BUSINESS_EMAIL = "you@example.com"   # <-- put your real email
BUSINESS_CITY_STATE = "Asheville, NC"


# =========================
# BASIC HELPERS
# =========================

def ensure_dirs():
    os.makedirs(BASE_DIR, exist_ok=True)
    os.makedirs(OUTGOING_DIR, exist_ok=True)
    os.makedirs(INVOICE_CSV_DIR, exist_ok=True)

    # Make sure JSON state file exists
    if not os.path.exists(INVOICE_STATE_JSON):
        data = {"next_number": 1, "invoices": []}
        save_json(INVOICE_STATE_JSON, data)

def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def prompt(msg, default=None):
    try:
        raw = input(msg).strip()
    except (EOFError, KeyboardInterrupt):
        print("\nAborted.")
        raise SystemExit(1)
    if not raw and default is not None:
        return default
    return raw

def prompt_float(msg, default=0.0):
    while True:
        val = prompt(msg, default=None)
        if val == "" and default is not None:
            return float(default)
        try:
            return float(val)
        except ValueError:
            print("Please enter a number (or leave blank for default).")


# =========================
# INVOICE NUMBERING
# =========================

def generate_invoice_number():
    state = load_json(INVOICE_STATE_JSON)
    next_num = state.get("next_number", 1)
    year = datetime.now().year
    invoice_no = f"GOODNUFF-{year}-{next_num:04d}"
    state["next_number"] = next_num + 1
    invoices_list = state.get("invoices", [])
    state["invoices"] = invoices_list
    save_json(INVOICE_STATE_JSON, state)
    return invoice_no, state

def record_invoice_meta(invoice_no, date_str, customer_name, vehicle_label,
                        grand_total, status, payment_method):
    # Update JSON meta
    state = load_json(INVOICE_STATE_JSON)
    invoices_list = state.get("invoices", [])
    invoices_list.append({
        "invoice_no": invoice_no,
        "date": date_str,
        "customer_name": customer_name,
        "vehicle": vehicle_label,
        "grand_total": grand_total,
        "status": status,
        "payment_method": payment_method,
    })
    state["invoices"] = invoices_list
    save_json(INVOICE_STATE_JSON, state)

    # Append to CSV for taxes
    new_file = not os.path.exists(INVOICE_CSV_PATH)
    with open(INVOICE_CSV_PATH, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if new_file:
            writer.writerow([
                "invoice_no", "date", "customer_name", "vehicle",
                "grand_total", "status", "payment_method"
            ])
        writer.writerow([
            invoice_no, date_str, customer_name, vehicle_label,
            f"{grand_total:.2f}", status, payment_method
        ])


# =========================
# HTML RENDER
# =========================

def build_html(invoice_no, date_str, customer, vehicle, concern,
               work_performed, recommendations, notes,
               labor_rate, labor_hours, labor_total,
               parts, parts_total, tax_rate, tax_amount,
               grand_total, status, payment_method):
    parts_rows = ""
    for p in parts:
        parts_rows += f"""
        <tr>
          <td>{p['desc']}</td>
          <td style="text-align:right;">${p['amount']:.2f}</td>
        </tr>"""

    html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{invoice_no} - {BUSINESS_NAME}</title>
  <style>
    body {{
      font-family: Arial, sans-serif;
      margin: 20px;
      color: #222;
    }}
    .header {{
      border-bottom: 2px solid #000;
      margin-bottom: 15px;
      padding-bottom: 10px;
    }}
    .header h1 {{
      margin: 0;
    }}
    .muted {{
      color: #666;
      font-size: 0.9em;
    }}
    .section-title {{
      font-weight: bold;
      margin-top: 18px;
      text-transform: uppercase;
      font-size: 0.9em;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
      margin-bottom: 8px;
    }}
    th, td {{
      padding: 6px;
      border: 1px solid #ddd;
      font-size: 0.9em;
      vertical-align: top;
    }}
    th {{
      background: #f4f4f4;
    }}
    .totals-table {{
      width: 40%;
      float: right;
      margin-top: 10px;
    }}
    .status-paid {{
      color: #0a0;
      font-weight: bold;
    }}
    .status-unpaid {{
      color: #a00;
      font-weight: bold;
    }}
    .clearfix::after {{
      content: "";
      display: table;
      clear: both;
    }}
    @media print {{
      .muted {{
        display: none !important;
      }}
      body {{
        margin: 0;
      }}
    }}
  </style>
</head>
<body>
  <div class="header">
    <h1>{BUSINESS_NAME}</h1>
    <div>{BUSINESS_OWNER}</div>
    <div>{BUSINESS_CITY_STATE}</div>
    <div>Phone: {BUSINESS_PHONE}</div>
    <div>Email: {BUSINESS_EMAIL}</div>
  </div>

  <div class="clearfix">
    <div style="float:left; width:55%;">
      <div class="section-title">Bill To</div>
      <div>{customer['name']}</div>
      <div>{customer['phone']}</div>
      <div>{customer['email']}</div>
      <div>{customer['address']}</div>
    </div>

    <div style="float:right; width:40%; text-align:right;">
      <div class="section-title">Invoice</div>
      <div><strong>Invoice #:</strong> {invoice_no}</div>
      <div><strong>Date:</strong> {date_str}</div>
      <div><strong>Status:</strong> 
        <span class="status-{'paid' if status == 'PAID' else 'unpaid'}">{status}</span>
      </div>
      <div><strong>Payment:</strong> {payment_method}</div>
    </div>
  </div>

  <div class="clearfix" style="margin-top:16px;">
    <div class="section-title">Vehicle</div>
    <table>
      <tr>
        <th>Year</th><th>Make</th><th>Model</th><th>VIN</th><th>Tag</th><th>Odometer</th>
      </tr>
      <tr>
        <td>{vehicle['year']}</td>
        <td>{vehicle['make']}</td>
        <td>{vehicle['model']}</td>
        <td>{vehicle['vin']}</td>
        <td>{vehicle['plate']}</td>
        <td>{vehicle['odometer']}</td>
      </tr>
    </table>
  </div>

  <div class="section-title">Customer Concern / Complaint</div>
  <p>{concern}</p>

  <div class="section-title">Work Performed</div>
  <p>{work_performed}</p>

  <div class="section-title">Recommendations / Notes</div>
  <p>{recommendations}</p>
  <p>{notes}</p>

  <div class="clearfix" style="margin-top:16px;">
    <div style="float:left; width:55%;">
      <div class="section-title">Labor</div>
      <table>
        <tr><th>Description</th><th>Rate</th><th>Hours</th><th>Line Total</th></tr>
        <tr>
          <td>Labor</td>
          <td>${labor_rate:.2f}/hr</td>
          <td>{labor_hours:.2f}</td>
          <td>${labor_total:.2f}</td>
        </tr>
      </table>

      <div class="section-title">Parts</div>
      <table>
        <tr><th>Description</th><th style="text-align:right;">Amount</th></tr>
        {parts_rows}
      </table>
    </div>

    <div style="float:right; width:40%;">
      <table class="totals-table">
        <tr><th>Subtotal</th><td style="text-align:right;">${labor_total + parts_total:.2f}</td></tr>
        <tr><th>Tax ({tax_rate*100:.2f}%)</th><td style="text-align:right;">${tax_amount:.2f}</td></tr>
        <tr><th>Grand Total</th><td style="text-align:right;"><strong>${grand_total:.2f}</strong></td></tr>
      </table>
    </div>
  </div>

  <div class="clearfix" style="margin-top:40px;">
    <div class="muted">
      Generated by garage invoice script. Keep this for your records.
    </div>
  </div>
</body>
</html>
"""
    return html


# =========================
# MAIN FLOW
# =========================

def main():
    ensure_dirs()

    print("===================================")
    print("   GOOD 'NUFF MOBILE MECHANIC")
    print("          NEW INVOICE")
    print("===================================\n")

    confirm = prompt("Create a new invoice? (y to continue, anything else to cancel): ")
    if confirm.lower() != "y":
        print("Cancelled.")
        return

    # Generate invoice number now so it's reserved
    invoice_no, _ = generate_invoice_number()
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d %H:%M")

    print(f"\nInvoice Number: {invoice_no}")
    print("(You'll enter this back into jobmenu after this script finishes.)\n")

    # --- Customer info ---
    print("=== Customer Info ===")
    cust_name = prompt("Customer name: ")
    cust_phone = prompt("Phone: ")
    cust_email = prompt("Email (optional): ")
    cust_address = prompt("Address or 'Residence': ")

    customer = {
        "name": cust_name,
        "phone": cust_phone,
        "email": cust_email,
        "address": cust_address,
    }

    # --- Vehicle info ---
    print("\n=== Vehicle Info ===")
    v_year = prompt("Year: ")
    v_make = prompt("Make: ")
    v_model = prompt("Model: ")
    v_vin = prompt("VIN (optional): ")
    v_plate = prompt("Tag / Plate (optional): ")
    v_odo = prompt("Odometer (optional): ")

    vehicle = {
        "year": v_year,
        "make": v_make,
        "model": v_model,
        "vin": v_vin,
        "plate": v_plate,
        "odometer": v_odo,
    }
    vehicle_label = f"{v_year} {v_make} {v_model}".strip()

    # --- Complaint / work / recs ---
    print("\n=== Diagnostic & Work Details ===")
    concern = prompt("Customer concern / complaint: ")
    work_performed = prompt("Work performed (summary): ")
    recommendations = prompt("Recommendations / next steps: ")
    notes = prompt("Extra notes (optional): ")

    # --- Money: labor ---
    print("\n=== Labor ===")
    labor_rate = prompt_float("Labor rate (default 90): ", default=90.0)
    labor_hours = prompt_float("Labor hours: ", default=0.0)
    labor_total = labor_rate * labor_hours

    # --- Money: parts ---
    print("\n=== Parts (leave description blank to stop) ===")
    parts = []
    while True:
        desc = prompt("Part description (blank to finish): ")
        if desc == "":
            break
        amount = prompt_float("  Amount for this part: ", default=0.0)
        parts.append({"desc": desc, "amount": amount})

    parts_total = sum(p["amount"] for p in parts)

    # --- Tax / totals ---
    print("\n=== Tax & Payment ===")
    tax_rate = prompt_float("Tax rate as percent (default 7 for 7%): ", default=7.0) / 100.0
    subtotal = labor_total + parts_total
    tax_amount = subtotal * tax_rate
    grand_total = subtotal + tax_amount

    paid_flag = prompt("Is this invoice PAID? (y/n, default n): ", default="n").lower()
    status = "PAID" if paid_flag == "y" else "UNPAID"
    payment_method = prompt("Payment method (cash, card, Zelle, etc.): ")

    # --- Build HTML ---
    html = build_html(
        invoice_no, date_str, customer, vehicle, concern,
        work_performed, recommendations, notes,
        labor_rate, labor_hours, labor_total,
        parts, parts_total, tax_rate, tax_amount,
        grand_total, status, payment_method
    )

    # --- Save files ---
    html_path = os.path.join(OUTGOING_DIR, f"{invoice_no}.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)

    record_invoice_meta(
        invoice_no, date_str, cust_name, vehicle_label,
        grand_total, status, payment_method
    )

    # --- Summary ---
    print("\n===================================")
    print("  INVOICE CREATED SUCCESSFULLY")
    print("===================================")
    print(f"Invoice #: {invoice_no}")
    print(f"Date     : {date_str}")
    print(f"Customer : {cust_name}")
    print(f"Vehicle  : {vehicle_label}")
    print(f"Status   : {status}")
    print(f"Total    : ${grand_total:.2f}")
    print(f"\nHTML saved to: {html_path}")
    print(f"CSV log at   : {INVOICE_CSV_PATH}")
    print("\nNow go back to jobmenu and enter this invoice number when it asks.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled by user.")