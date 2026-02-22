cat << 'EOF' > ~/garage/jobmenu
#!/usr/bin/env python3
"""
GOOD 'NUFF GARAGE - Customer Menu (clean version)

Data file:
  /home/goodnuffmechanic/garage/.business/customers/customers.csv
"""

import csv
from pathlib import Path
from datetime import datetime

BUSINESS = Path("/home/goodnuffmechanic/garage/.business")
CUSTOMERS_CSV = BUSINESS / "customers" / "customers.csv"


def load_customers():
    """Return list of dict rows from customers.csv."""
    rows = []
    if not CUSTOMERS_CSV.exists():
        return rows

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
        # if empty, just keep the header we created earlier
        return

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
        writer.writerows(rows)


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

    new_row = {
        "customer_id": cid,
        "name": name,
        "phone": phone,
        "email": email,
        "vehicle": vehicle,
        "plate_or_vin": plate,
        "social_media": social,
        "created_at": created_at,
    }

    rows.append(new_row)
    save_customers(rows)

    print(f"\nAdded customer #{cid}: {name}\n")
    input("Press Enter to return to menu...")


def main():
    while True:
        print("\n=== GOOD 'NUFF GARAGE - CUSTOMER MENU ===")
        print("1) List all customers")
        print("2) Add new customer")
        print("3) Quit\n")

        choice = input("Select: ").strip().lower()

        if choice == "1":
            list_all_customers()
        elif choice == "2":
            add_new_customer()
        elif choice in ("3", "q"):
            print("Exiting customer menu...")
            return
        else:
            print("Invalid choice.\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting customer menu.\n")
EOF