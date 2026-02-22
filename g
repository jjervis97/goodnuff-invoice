#!/usr/bin/env python3
import os
import json
import subprocess
from datetime import datetime

# ====== CONFIG ======
# Base directory for business data
BASE_DIR = os.path.expanduser("~/garage/.business")

# JSON data files (new system)
CUSTOMERS_FILE = os.path.join(BASE_DIR, "customers.json")
JOBS_FILE = os.path.join(BASE_DIR, "jobs.json")
DIAG_FILE = os.path.join(BASE_DIR, "diagnostics.json")

# Path to your existing invoice program
INVOICE_SCRIPT = os.path.expanduser("~/garage/invoice")


# ====== STORAGE HELPERS ======

def ensure_storage():
    """
    Make sure base directory and JSON files exist.
    Does NOT touch your existing CSVs; those stay as backup.
    """
    os.makedirs(BASE_DIR, exist_ok=True)

    if not os.path.exists(CUSTOMERS_FILE):
        data = {"next_customer_id": 1, "customers": []}
        save_json(CUSTOMERS_FILE, data)

    if not os.path.exists(JOBS_FILE):
        data = {"next_job_id": 1, "jobs": []}
        save_json(JOBS_FILE, data)

    if not os.path.exists(DIAG_FILE):
        data = {"next_log_id": 1, "logs": []}
        save_json(DIAG_FILE, data)


def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def pause(msg="\nPress ENTER to continue..."):
    try:
        input(msg)
    except (EOFError, KeyboardInterrupt):
        pass


def clear_screen():
    os.system("clear" if os.name == "posix" else "cls")


def prompt(prompt_text):
    try:
        return input(prompt_text).strip()
    except (EOFError, KeyboardInterrupt):
        print("\nReturning to menu.")
        return ""


# ====== CUSTOMER MANAGEMENT ======

def get_customers():
    data = load_json(CUSTOMERS_FILE)
    return data.get("customers", []), data.get("next_customer_id", 1)


def save_customers(customers, next_id):
    data = {"next_customer_id": next_id, "customers": customers}
    save_json(CUSTOMERS_FILE, data)


def list_customers(customers):
    if not customers:
        print("\nNo customers found yet.")
        return
    print("\n=== Customers ===")
    for c in customers:
        print(f"{c['id']:3} | {c['name']} | {c.get('phone', '')} | {c.get('email', '')}")


def search_customers(customers, term):
    term_lower = term.lower()
    return [
        c for c in customers
        if term_lower in str(c.get("name", "")).lower()
        or term_lower in str(c.get("phone", "")).lower()
        or term_lower in str(c.get("email", "")).lower()
    ]


def select_customer(customers, allow_search=True):
    """
    Helper: list/search and pick a customer by ID.
    Returns the customer dict, or None.
    """
    while True:
        clear_screen()
        print("=== Select Customer ===")
        list_customers(customers)
        print("\nOptions:")
        print("  ID  = select customer by ID")
        if allow_search:
            print("  s   = search")
        print("  b   = back")

        choice = prompt("> ").lower()

        if choice in ("b", ""):
            return None
        if allow_search and choice == "s":
            term = prompt("Search term (name/phone/email): ")
            if not term:
                continue
            matches = search_customers(customers, term)
            clear_screen()
            print(f"=== Search results for '{term}' ===")
            list_customers(matches)
            pause()
            continue

        # try ID
        try:
            cid = int(choice)
        except ValueError:
            print("Invalid choice. Use a customer ID, 's', or 'b'.")
            pause()
            continue

        for c in customers:
            if c["id"] == cid:
                return c

        print(f"No customer with ID {cid}.")
        pause()


def add_customer():
    customers, next_id = get_customers()

    clear_screen()
    print("=== Add New Customer ===")
    name = prompt("Customer name: ")
    if not name:
        print("Name is required. Aborting.")
        pause()
        return

    phone = prompt("Phone (optional): ")
    email = prompt("Email (optional): ")
    notes = prompt("Initial note (optional): ")

    customer = {
        "id": next_id,
        "name": name,
        "phone": phone,
        "email": email,
        "notes": [],
        "vehicles": []  # each: {id, year, make, model, vin, plate}
    }
    if notes:
        customer["notes"].append({
            "date": datetime.now().isoformat(timespec="seconds"),
            "text": notes
        })

    customers.append(customer)
    next_id += 1
    save_customers(customers, next_id)

    print(f"\nCustomer added with ID {customer['id']}.")
    pause()


def add_vehicle_to_customer(customer):
    clear_screen()
    print(f"=== Add Vehicle for {customer['name']} ===")
    year = prompt("Year (e.g., 2007): ")
    make = prompt("Make (e.g., Ford): ")
    model = prompt("Model (e.g., Ranger): ")
    vin = prompt("VIN (optional): ")
    plate = prompt("Tag / Plate (optional): ")

    if "vehicles" not in customer:
        customer["vehicles"] = []

    vehicle_id = 1
    if customer["vehicles"]:
        vehicle_id = max(v["id"] for v in customer["vehicles"]) + 1

    vehicle = {
        "id": vehicle_id,
        "year": year,
        "make": make,
        "model": model,
        "vin": vin,
        "plate": plate
    }
    customer["vehicles"].append(vehicle)
    print("\nVehicle added.")
    pause()


def add_note_to_customer(customer):
    clear_screen()
    print(f"=== Add Note for {customer['name']} ===")
    text = prompt("Note: ")
    if not text:
        print("No note entered.")
        pause()
        return

    if "notes" not in customer:
        customer["notes"] = []

    customer["notes"].append({
        "date": datetime.now().isoformat(timespec="seconds"),
        "text": text
    })
    print("Note added.")
    pause()


def show_job_history_for_customer(customer):
    jobs, _ = get_jobs()
    cust_jobs = [j for j in jobs if j.get("customer_id") == customer["id"]]
    clear_screen()
    print(f"=== Job History for {customer['name']} ===")

    if not cust_jobs:
        print("No jobs recorded yet.")
        pause()
        return

    for j in sorted(cust_jobs, key=lambda x: x["id"], reverse=True):
        print(
            f"ID {j['id']:3} | {j['date']} | "
            f"{j.get('description','')} | "
            f"Invoice: {j.get('invoice_id','')} | "
            f"Status: {j.get('status','')}"
        )

    pause()


def show_diag_logs_for_customer(customer):
    logs, _ = get_logs()
    cust_logs = [l for l in logs if l.get("customer_id") == customer["id"]]

    clear_screen()
    print(f"=== Diagnostic Logs for {customer['name']} ===")
    if not cust_logs:
        print("No logs for this customer yet.")
        pause()
        return

    for l in sorted(cust_logs, key=lambda x: x["id"], reverse=True):
        print(f"ID {l['id']:3} | {l['date']}")
        if l.get("concern"):
            print(f"  Concern      : {l['concern']}")
        if l.get("codes"):
            print(f"  Codes        : {l['codes']}")
        if l.get("findings"):
            print(f"  Findings     : {l['findings']}")
        if l.get("recommendation"):
            print(f"  Recommendation: {l['recommendation']}")
        print("-" * 60)

    pause()


def show_customer_detail():
    customers, next_id = get_customers()
    if not customers:
        print("\nNo customers yet.")
        pause()
        return

    customer = select_customer(customers)
    if not customer:
        return

    while True:
        clear_screen()
        print(f"=== Customer Detail: {customer['name']} (ID {customer['id']}) ===")
        print(f"Phone : {customer.get('phone', '')}")
        print(f"Email : {customer.get('email', '')}")

        # Vehicles
        print("\nVehicles:")
        vehicles = customer.get("vehicles", [])
        if not vehicles:
            print("  (none yet)")
        else:
            for v in vehicles:
                label = f"{v.get('year','')} {v.get('make','')} {v.get('model','')}".strip()
                extra = []
                if v.get("plate"):
                    extra.append(f"Plate {v['plate']}")
                if v.get("vin"):
                    extra.append(f"VIN {v['vin']}")
                extra_str = " | ".join(extra)
                print(f"  {v['id']}: {label} {('- ' + extra_str) if extra_str else ''}")

        # Notes (show last 3)
        print("\nRecent Notes:")
        notes = customer.get("notes", [])
        if not notes:
            print("  (none)")
        else:
            for note in notes[-3:]:
                print(f"  - {note['date']}: {note['text']}")

        # Job & diag counts
        jobs_data = load_json(JOBS_FILE)
        jobs = jobs_data.get("jobs", [])
        customer_jobs = [j for j in jobs if j.get("customer_id") == customer["id"]]

        diag_data = load_json(DIAG_FILE)
        logs = diag_data.get("logs", [])
        customer_logs = [l for l in logs if l.get("customer_id") == customer["id"]]

        print(f"\nJobs on file        : {len(customer_jobs)}")
        print(f"Diagnostic log items: {len(customer_logs)}")

        print("\nOptions:")
        print("1) Add Note")
        print("2) Add Vehicle")
        print("3) View Job History")
        print("4) View Diagnostic Logs")
        print("5) Back to previous menu")

        choice = prompt("> ")

        if choice == "1":
            add_note_to_customer(customer)
            save_customers(customers, next_id)
        elif choice == "2":
            add_vehicle_to_customer(customer)
            save_customers(customers, next_id)
        elif choice == "3":
            show_job_history_for_customer(customer)
        elif choice == "4":
            show_diag_logs_for_customer(customer)
        elif choice in ("5", ""):
            save_customers(customers, next_id)
            return
        else:
            print("Invalid choice.")
            pause()


def customer_management_menu():
    while True:
        clear_screen()
        print("=== Customer Management ===")
        print("1) List Customers")
        print("2) Search Customers")
        print("3) Add New Customer")
        print("4) View Customer Detail")
        print("5) Back to Main Menu")

        choice = prompt("> ")

        if choice == "1":
            customers, _ = get_customers()
            clear_screen()
            list_customers(customers)
            pause()
        elif choice == "2":
            customers, _ = get_customers()
            term = prompt("Search term: ")
            if not term:
                continue
            matches = search_customers(customers, term)
            clear_screen()
            print(f"=== Results for '{term}' ===")
            list_customers(matches)
            pause()
        elif choice == "3":
            add_customer()
        elif choice == "4":
            show_customer_detail()
        elif choice in ("5", ""):
            return
        else:
            print("Invalid choice.")
            pause()


# ====== JOB / INVOICE MANAGEMENT ======

def get_jobs():
    data = load_json(JOBS_FILE)
    return data.get("jobs", []), data.get("next_job_id", 1)


def save_jobs(jobs, next_id):
    data = {"next_job_id": next_id, "jobs": jobs}
    save_json(JOBS_FILE, data)


def launch_invoice_program():
    """
    Try to launch your invoice program at ~/garage/invoice.
    If it's a .py, run with python3. Otherwise, execute directly.
    """
    if not os.path.exists(INVOICE_SCRIPT):
        print(f"\nInvoice script not found at {INVOICE_SCRIPT}")
        return

    print("\nLaunching invoice program...")
    try:
        if INVOICE_SCRIPT.endswith(".py"):
            subprocess.run(["python3", INVOICE_SCRIPT], check=False)
        else:
            subprocess.run([INVOICE_SCRIPT], check=False)
    except Exception as e:
        print(f"Warning: could not run invoice script: {e}")


def create_new_job():
    # Select customer first
    customers, _ = get_customers()
    if not customers:
        print("\nYou need at least one customer before creating a job.")
        pause()
        return

    customer = select_customer(customers)
    if not customer:
        return

    # Select vehicle (or none)
    vehicles = customer.get("vehicles", [])
    vehicle_id = None
    if vehicles:
        print("\nSelect vehicle for this job (or ENTER to skip):")
        for v in vehicles:
            label = f"{v.get('year','')} {v.get('make','')} {v.get('model','')}".strip()
            print(f"  {v['id']}: {label}")
        v_choice = prompt("> ")
        if v_choice:
            try:
                v_id_int = int(v_choice)
                for v in vehicles:
                    if v["id"] == v_id_int:
                        vehicle_id = v_id_int
                        break
            except ValueError:
                pass

    description = prompt("\nShort job description (e.g., 'Front brakes, diag'): ")

    # Run invoice program and ask what invoice number it produced
    launch_invoice_program()
    print("\nIf an invoice number was generated (e.g., GOODNUFF-2026-0001),")
    invoice_id = prompt("Enter that invoice number (or leave blank): ")

    jobs, next_job_id = get_jobs()
    job = {
        "id": next_job_id,
        "customer_id": customer["id"],
        "vehicle_id": vehicle_id,
        "date": datetime.now().isoformat(timespec="seconds"),
        "description": description,
        "invoice_id": invoice_id,
        "status": "open"
    }
    jobs.append(job)
    next_job_id += 1
    save_jobs(jobs, next_job_id)

    print(f"\nJob created with internal ID {job['id']}.")
    pause()


def list_recent_jobs(limit=20):
    jobs, _ = get_jobs()
    if not jobs:
        print("\nNo jobs recorded yet.")
        return
    customers, _ = get_customers()
    customers_by_id = {c["id"]: c for c in customers}

    print(f"\n=== Recent Jobs (up to {limit}) ===")
    for job in sorted(jobs, key=lambda j: j["id"], reverse=True)[:limit]:
        cname = customers_by_id.get(job["customer_id"], {}).get("name", "Unknown")
        print(
            f"ID {job['id']:3} | {job['date']} | "
            f"{cname} | {job.get('description', '')} | "
            f"Invoice: {job.get('invoice_id','')}"
        )


def search_jobs_by_customer_name():
    customers, _ = get_customers()
    jobs, _ = get_jobs()
    if not jobs:
        print("\nNo jobs yet.")
        pause()
        return

    term = prompt("Customer name search term: ")
    if not term:
        return

    term_lower = term.lower()
    matches = [c for c in customers if term_lower in c.get("name", "").lower()]
    if not matches:
        print("No customers matched that name.")
        pause()
        return

    customers_by_id = {c["id"]: c for c in matches}
    ids = set(customers_by_id.keys())
    filtered_jobs = [j for j in jobs if j.get("customer_id") in ids]

    clear_screen()
    print(f"=== Jobs for matching customers ('{term}') ===")
    if not filtered_jobs:
        print("No jobs for those customers.")
    else:
        for j in sorted(filtered_jobs, key=lambda x: x["id"], reverse=True):
            cname = customers_by_id.get(j["customer_id"], {}).get("name", "Unknown")
            print(
                f"ID {j['id']:3} | {j['date']} | "
                f"{cname} | {j.get('description','')} | "
                f"Invoice: {j.get('invoice_id','')}"
            )

    pause()


def job_management_menu():
    while True:
        clear_screen()
        print("=== Job / Invoice Management ===")
        print("1) Create New Job (launch invoice)")
        print("2) List Recent Jobs")
        print("3) Search Jobs by Customer Name")
        print("4) Back to Main Menu")

        choice = prompt("> ")

        if choice == "1":
            create_new_job()
        elif choice == "2":
            clear_screen()
            list_recent_jobs()
            pause()
        elif choice == "3":
            search_jobs_by_customer_name()
            pause()
        elif choice in ("4", ""):
            return
        else:
            print("Invalid choice.")
            pause()


# ====== NOTES & DIAGNOSTIC LOGS ======

def get_logs():
    data = load_json(DIAG_FILE)
    return data.get("logs", []), data.get("next_log_id", 1)


def save_logs(logs, next_id):
    data = {"next_log_id": next_id, "logs": logs}
    save_json(DIAG_FILE, data)


def add_diag_log_quick():
    customers, _ = get_customers()
    if not customers:
        print("\nYou need a customer before adding logs.")
        pause()
        return

    customer = select_customer(customers)
    if not customer:
        return

    vehicles = customer.get("vehicles", [])
    vehicle_id = None
    if vehicles:
        print("\nSelect vehicle for this log (or ENTER to skip):")
        for v in vehicles:
            label = f"{v.get('year','')} {v.get('make','')} {v.get('model','')}".strip()
            print(f"  {v['id']}: {label}")
        v_choice = prompt("> ")
        if v_choice:
            try:
                v_id_int = int(v_choice)
                for v in vehicles:
                    if v["id"] == v_id_int:
                        vehicle_id = v_id_int
                        break
            except ValueError:
                pass

    clear_screen()
    print(f"=== New Diagnostic Log for {customer['name']} ===")
    concern = prompt("Customer concern / complaint: ")
    findings = prompt("Your findings (what you observed): ")
    codes = prompt("OBD-II codes (comma separated, optional): ")
    recommendation = prompt("Recommendations / next steps: ")

    logs, next_log_id = get_logs()
    log_item = {
        "id": next_log_id,
        "customer_id": customer["id"],
        "vehicle_id": vehicle_id,
        "date": datetime.now().isoformat(timespec="seconds"),
        "concern": concern,
        "findings": findings,
        "codes": codes,
        "recommendation": recommendation
    }
    logs.append(log_item)
    next_log_id += 1
    save_logs(logs, next_log_id)

    print("\nDiagnostic log saved.")
    pause()


def show_recent_logs(limit=20):
    logs, _ = get_logs()
    if not logs:
        print("\nNo diagnostic logs yet.")
        return

    customers, _ = get_customers()
    customers_by_id = {c["id"]: c for c in customers}

    print(f"\n=== Recent Diagnostic Logs (up to {limit}) ===")
    for l in sorted(logs, key=lambda x: x["id"], reverse=True)[:limit]:
        cname = customers_by_id.get(l["customer_id"], {}).get("name", "Unknown")
        print(f"ID {l['id']:3} | {l['date']} | {cname}")
        print(f"  Concern      : {l.get('concern','')}")
        if l.get("codes"):
            print(f"  Codes        : {l['codes']}")
        print(f"  Findings     : {l.get('findings','')}")
        print(f"  Recommendation: {l.get('recommendation','')}")
        print("-" * 60)


def notes_diag_menu():
    while True:
        clear_screen()
        print("=== Notes & Diagnostic Logs ===")
        print("1) Quick New Diagnostic Log")
        print("2) View Recent Diagnostic Logs")
        print("3) Back to Main Menu")

        choice = prompt("> ")

        if choice == "1":
            add_diag_log_quick()
        elif choice == "2":
            clear_screen()
            show_recent_logs()
            pause()
        elif choice in ("3", ""):
            return
        else:
            print("Invalid choice.")
            pause()


# ====== SETTINGS ======

def settings_menu():
    while True:
        clear_screen()
        print("=== Settings ===")
        print(f"Storage base directory: {BASE_DIR}")
        print(f"Customers file        : {CUSTOMERS_FILE}")
        print(f"Jobs file             : {JOBS_FILE}")
        print(f"Diagnostics file      : {DIAG_FILE}")
        print(f"Invoice script path   : {INVOICE_SCRIPT}")
        print("\nOptions:")
        print("1) Test launch invoice script")
        print("2) Back to Main Menu")

        choice = prompt("> ")

        if choice == "1":
            launch_invoice_program()
            pause()
        elif choice in ("2", ""):
            return
        else:
            print("Invalid choice.")
            pause()


# ====== MAIN MENU ======

def main_menu():
    ensure_storage()
    while True:
        clear_screen()
        print("===================================")
        print("  GOOD 'NUFF MOBILE MECHANIC")
        print("  JOB / CUSTOMER CONTROL PANEL")
        print("===================================\n")
        print("1) Customer Management")
        print("2) Job / Invoice Management")
        print("3) Notes & Diagnostic Logs")
        print("4) Settings")
        print("5) Exit")

        choice = prompt("> ")

        if choice == "1":
            customer_management_menu()
        elif choice == "2":
            job_management_menu()
        elif choice == "3":
            notes_diag_menu()
        elif choice == "4":
            settings_menu()
        elif choice in ("5", ""):
            print("\nGoodbye.")
            break
        else:
            print("Invalid choice.")
            pause()


if __name__ == "__main__":
    try:
        main_menu()
    except KeyboardInterrupt:
        print("\nExiting.")