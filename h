mkdir -p ~/garage/.business/expenses

cat << 'EOF' > ~/garage/expenses
#!/usr/bin/env python3
"""
GOOD 'NUFF GARAGE - Expenses & Write-Offs Tracker

Stores data in:
  ~/garage/.business/expenses/expenses.csv

Columns:
  expense_id,date,category,amount,payment_method,notes
"""

from pathlib import Path
from datetime import datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import csv

HOME = Path("/home/goodnuffmechanic")
EXP_DIR = HOME / "garage" / ".business" / "expenses"
EXP_CSV = EXP_DIR / "expenses.csv"

FIELDNAMES = [
    "expense_id",
    "date",
    "category",
    "amount",
    "payment_method",
    "notes",
]


def pause(msg="\nPress Enter to return to menu..."):
    try:
        input(msg)
    except EOFError:
        pass


def money(val: Decimal) -> Decimal:
    return val.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def ensure_csv():
    EXP_DIR.mkdir(parents=True, exist_ok=True)
    if not EXP_CSV.exists():
        with EXP_CSV.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
            writer.writeheader()


def load_expenses():
    ensure_csv()
    rows = []
    with EXP_CSV.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def save_expenses(rows):
    ensure_csv()
    with EXP_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)


def next_expense_id(rows):
    max_id = 0
    for r in rows:
        try:
            eid = int(r.get("expense_id", "0"))
            if eid > max_id:
                max_id = eid
        except ValueError:
            continue
    return str(max_id + 1)


def add_expense():
    rows = load_expenses()
    print("\n=== ADD NEW EXPENSE ===\n")

    today = datetime.now().strftime("%Y-%m-%d")
    date_raw = input(f"Date [{today}]: ").strip()
    if not date_raw:
        date_raw = today

    category = input("Category (tools, gas, parts, fluids, etc): ").strip() or "misc"

    while True:
        amt_raw = input("Amount (e.g. 45.50): ").strip()
        try:
            amount = money(Decimal(amt_raw))
            break
        except (InvalidOperation, ValueError):
            print("Invalid amount. Try again.")

    payment_method = input("Payment method (cash, card, app, etc): ").strip() or "N/A"
    notes = input("Notes (optional): ").strip()

    eid = next_expense_id(rows)

    row = {
        "expense_id": eid,
        "date": date_raw,
        "category": category,
        "amount": str(amount),
        "payment_method": payment_method,
        "notes": notes,
    }
    rows.append(row)
    save_expenses(rows)

    print(f"\nAdded expense #{eid} - {category} - ${amount}")
    pause()


def view_recent(limit=20):
    rows = load_expenses()
    print("\n=== RECENT EXPENSES ===\n")

    if not rows:
        print("No expenses logged yet.")
        pause()
        return

    # Show last N by order added
    subset = rows[-limit:]
    total = Decimal("0.00")

    for r in subset:
        try:
            amt = Decimal(r.get("amount", "0"))
        except InvalidOperation:
            amt = Decimal("0.00")
        total += amt

        print(
            f"#{r.get('expense_id','')} | {r.get('date','')} | "
            f"{r.get('category','')} | ${amt} | {r.get('payment_method','')}"
        )
        note = r.get("notes", "").strip()
        if note:
            print(f"   Notes: {note}")

    print("\nTotal (these rows): $", money(total))
    pause()


def view_by_category():
    rows = load_expenses()
    if not rows:
        print("\nNo expenses logged yet.")
        pause()
        return

    cat = input("\nCategory to filter by (case-insensitive): ").strip()
    if not cat:
        print("Cancelled.")
        pause()
        return

    cat_lower = cat.lower()
    filtered = [r for r in rows if r.get("category", "").lower() == cat_lower]

    print(f"\n=== EXPENSES IN CATEGORY: {cat} ===\n")

    if not filtered:
        print("No expenses found for this category.")
        pause()
        return

    total = Decimal("0.00")
    for r in filtered:
        try:
            amt = Decimal(r.get("amount", "0"))
        except InvalidOperation:
            amt = Decimal("0.00")
        total += amt

        print(
            f"#{r.get('expense_id','')} | {r.get('date','')} | "
            f"${amt} | {r.get('payment_method','')}"
        )
        note = r.get("notes", "").strip()
        if note:
            print(f"   Notes: {note}")

    print(f"\nTotal in category '{cat}': ${money(total)}")
    pause()


def main():
    ensure_csv()
    while True:
        print("\n=== EXPENSES & WRITE-OFFS ===\n")
        print("1) Add new expense")
        print("2) View recent expenses")
        print("3) View expenses by category")
        print("4) Quit\n")

        choice = input("Select: ").strip()

        if choice == "1":
            add_expense()
        elif choice == "2":
            view_recent()
        elif choice == "3":
            view_by_category()
        elif choice in ("4", "q", "Q"):
            break
        else:
            print("Invalid choice.")
            pause()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting expenses menu...\n")
EOF