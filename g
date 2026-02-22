cat << 'EOF' > ~/garage/gn
#!/usr/bin/env python3
"""
GOOD 'NUFF GARAGE - Main launcher (customers, invoices, expenses)
"""

import os
import sys
import subprocess
from pathlib import Path

HOME = Path("/home/goodnuffmechanic")
GARAGE = HOME / "garage"
BUSINESS = GARAGE / ".business"
OUTGOING = HOME / "Outgoing"


def pause(msg="\nPress Enter to return to menu..."):
    try:
        input(msg)
    except EOFError:
        pass


def run_customer_menu():
    """Call your customer menu script in ~/garage."""
    script = GARAGE / "jobmenu"
    if not script.exists():
        print(f"\nERROR: customer menu not found at {script}")
        pause()
        return
    try:
        subprocess.run([str(script)])
    except Exception as e:
        print(f"\nERROR running customer menu: {e}")
        pause()


def run_invoice():
    """Launch the invoice generator in ~/garage."""
    script = GARAGE / "invoice"
    if not script.exists():
        print(f"\nERROR: invoice script not found at {script}")
        pause()
        return
    try:
        subprocess.run([str(script)])
    except Exception as e:
        print(f"\nERROR running invoice script: {e}")
        pause()


def view_invoice_history():
    """List recent HTML invoices in Outgoing and open one."""
    OUTGOING.mkdir(parents=True, exist_ok=True)
    files = sorted(
        OUTGOING.glob("GN-*.html"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )

    if not files:
        print("\nNo invoices found in Outgoing yet.")
        pause()
        return

    print("\n=== INVOICE HISTORY (HTML copies) ===\n")
    max_show = min(len(files), 25)
    for i in range(max_show):
        f = files[i]
        print(f"{i+1}) {f.name}")

    print("\nEnter invoice # to open, or just Enter to cancel.")
    choice = input("Select: ").strip()
    if not choice:
        return
    if not choice.isdigit():
        print("Invalid selection.")
        pause()
        return

    idx = int(choice)
    if idx < 1 or idx > max_show:
        print("Out of range.")
        pause()
        return

    target = files[idx - 1]
    print(f"\nOpening {target} ...\n")

    try:
        rc = subprocess.run(["xdg-open", str(target)]).returncode
        if rc != 0:
            raise RuntimeError
    except Exception:
        subprocess.run(["less", str(target)])


def system_tools():
    """Simple info screen for now."""
    print("\n=== SYSTEM / TOOLS ===\n")
    print(f"Garage root : {GARAGE}")
    print(f"Business dir: {BUSINESS}")
    print(f"Outgoing dir: {OUTGOING}")
    print("\nThis is just an info screen for now. We can add backup/check tools later.")
    pause()


def run_expenses():
    """Launch the expenses tracker in ~/garage."""
    script = GARAGE / "expenses"
    if not script.exists():
        print(f"\nERROR: expenses script not found at {script}")
        pause()
        return
    try:
        subprocess.run([str(script)])
    except Exception as e:
        print(f"\nERROR running expenses script: {e}")
        pause()


def main():
    OUTGOING.mkdir(parents=True, exist_ok=True)

    while True:
        os.system("clear")
        print("=== GOOD 'NUFF GARAGE ===\n")
        print("1) Customer Menu")
        print("2) Create New Invoice")
        print("3) View Invoice History")
        print("4) System / Tools")
        print("5) Expenses & Write-Offs")
        print("6) Exit\n")

        choice = input("Choose an option [1-6]: ").strip()

        if choice == "1":
            run_customer_menu()
        elif choice == "2":
            run_invoice()
        elif choice == "3":
            view_invoice_history()
        elif choice == "4":
            system_tools()
        elif choice == "5":
            run_expenses()
        elif choice in ("6", "q", "Q"):
            print("\nGood 'Nuff out.\n")
            break
        else:
            print("\nInvalid choice.")
            pause()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting...\n")
        sys.exit(0)
EOF