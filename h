#!/usr/bin/env python3
"""
GOOD 'NUFF GARAGE - Customer Menu (Simple Stable Version)

Path layout (fixed):
  Business home: /home/goodnuffmechanic/drive/GN_business_data/.business
  Customers CSV: /home/goodnuffmechanic/drive/GN_business_data/.business/customers/customers.csv
  Invoice script: /home/goodnuffmechanic/drive/GN_business_data/.business/invoices/invoice.py

Menu:
  1) List all customers
  2) Add new customer
  3) Add invoice for existing customer
  4) Quit (return to gn)
"""

import csv
import os
from pathlib import Path
from datetime import datetime

BUSINESS = Path("/home/goodnuffmechanic/drive/GN_business_data/.business")
CUSTOMERS_CSV = BUSINESS / "customers" / "customers.csv"
INVOICE_SCRIPT = BUSINESS / "invoices" / "invoice.py"


# ----------------- CSV HELPERS ----------------- #

def ensure_customers_file():
    """Make sure customers.csv exists with a reasonable header."""
    if CUSTOMERS_CSV.exists():
        return

    CUSTOMERS_CSV.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "customer_id",
        "name",
        "phone",
        "email",
        "vehicle",
        "plate_or_vin",
        "social_media",
        "created_at",
    ]
    with CUSTOMERS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()


def load_customers():
    """Return list of dict rows from customers.csv."""
    ensure_customers_file()
    rows = []
    try:
        with CUSTOMERS_CSV.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                rows.append(row)
    except Exception as e:
        print("\nERROR loading customers.csv:", e)
    return rows


def save_customers(rows):
    """Write all customer rows back to customers.csv."""
    if not rows:
        # If empty, keep header only
        ensure_customers_file()
        return

    fieldnames = list(rows[0].keys())
    with CUSTOMERS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


# ----------------- MENU ----------------- #

def main():
    while True:
        print("\n=== GOOD 'NUFF GARAGE - CUSTOMER MENU ===")
        print("1) List all customers")
        print("2) Add new customer")
        print("3) Add invoice for existing customer")
        print("4) Quit\n")

        choice = input("Select: ").strip().lower()

        if choice == "1":
            list_all_customers()
        elif choice == "2":
            add_new_customer()
        elif choice == "3":
            invoice_for_existing_customer()
        elif choice in ("4", "q"):
            # This will drop you back to gn, which is what you like
            print("Returning to GN...")
            return
        else:
            print("Invalid choice.\n")


# ----------------- OPTION 1: LIST CUSTOMERS ----------------- #

def list_all_customers():
    rows = load_customers()
    if not rows:
        print("\nNo customers found yet.\n")
        input("Press Enter to return to menu...")
        return

    print("\n=== ALL CUSTOMERS ===")
    for i, r in enumerate(rows, start=1):
        name = r.get("name", "")
        vehicle = r.get("vehicle", "")
        phone = r.get("phone", "")
        line = f"{i}) {name}"
        if vehicle:
            line += f" — {vehicle}"
        if phone:
            line += f" — {phone}"
        print(line)
    print()
    input("Press Enter to return to menu...")


# ----------------- OPTION 2: ADD NEW CUSTOMER ----------------- #

def next_customer_id(rows):
    """Compute the next numeric customer_id based on existing rows."""
    ids = []
    for r in rows:
        cid = str(r.get("customer_id", "")).strip()
        if cid.isdigit():
            ids.append(int(cid))
    if ids:
        return str(max(ids) + 1)
    return "1"


def add_new_customer():
    rows = load_customers()

    print("\n=== ADD NEW CUSTOMER ===")
    name = input("Name (required): ").strip()
    if not name:
        print("Name is required. Cancelled.\n")
        input("Press Enter to return to menu...")
        return

    phone = input("Phone: ").strip()
    email = input("Email: ").strip()
    vehicle = input("Vehicle (Year Make Model): ").strip()
    plate = input("Plate or VIN: ").strip()
    social = input("Social media / how they found you: ").strip()

    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cid = next_customer_id(rows)

    # Build row using a stable set of keys; keep any extra keys blank
    if rows:
        fieldnames = list(rows[0].keys())
    else:
        fieldnames = [
            "customer_id",
            "name",
            "phone",
            "email",
            "vehicle",
            "plate_or_vin",
            "social_media",
            "created_at",
        ]

    new_row = {}
    for f in fieldnames:
        if f == "customer_id":
            new_row[f] = cid
        elif f == "name":
            new_row[f] = name
        elif f == "phone":
            new_row[f] = phone
        elif f == "email":
            new_row[f] = email
        elif f == "vehicle":
            new_row[f] = vehicle
        elif f in ("plate_or_vin", "plate", "vin"):
            new_row[f] = plate
        elif f in ("social_media", "social", "source"):
            new_row[f] = social
        elif f in ("created_at", "created", "first_seen"):
            new_row[f] = created_at
        else:
            new_row[f] = ""  # unknown/extra column

    rows.append(new_row)
    save_customers(rows)

    print(f"\nAdded customer #{cid}: {name}\n")
    input("Press Enter to return to menu...")


# ----------------- OPTION 3: INVOICE FOR EXISTING CUSTOMER ----------------- #

def pick_customer(rows):
    """Show a simple list and let user choose one; return row or None."""
    if not rows:
        print("\nNo customers available.\n")
        input("Press Enter to return to menu...")
        return None

    print("\n=== SELECT CUSTOMER ===")
    for i, r in enumerate(rows, start=1):
        name = r.get("name", "")
        vehicle = r.get("vehicle", "")
        phone = r.get("phone", "")
        line = f"{i}) {name}"
        if vehicle:
            line += f" — {vehicle}"
        if phone:
            line += f" — {phone}"
        print(line)

    choice = input("\nSelect customer # (or Enter to cancel): ").strip()
    if not choice:
        return None
    if not choice.isdigit():
        print("\nInvalid selection.\n")
        input("Press Enter to return to menu...")
        return None

    idx = int(choice) - 1
    if 0 <= idx < len(rows):
        return rows[idx]

    print("\nInvalid selection.\n")
    input("Press Enter to return to menu...")
    return None


def invoice_for_existing_customer():
    rows = load_customers()
    customer = pick_customer(rows)
    if not customer:
        return

    print("\nStarting invoice for:")
    print(f"  Name:    {customer.get('name','')}")
    print(f"  Phone:   {customer.get('phone','')}")
    print(f"  Vehicle: {customer.get('vehicle','')}")
    print("\nWhen the invoice window opens, fill it out like normal.")
    print("When you quit the invoice, you'll return here.\n")

    if not INVOICE_SCRIPT.exists():
        print(f"ERROR: Invoice script not found at:\n  {INVOICE_SCRIPT}\n")
        input("Press Enter to return to menu...")
        return

    # Run your existing invoice.py script
    os.system(f'python3 "{INVOICE_SCRIPT}"')
    # When it exits, we come back to this menu


# ----------------- ENTRYPOINT ----------------- #

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        # So Ctrl+C doesn't throw an ugly traceback
        print("\nExiting customer menu.\n")