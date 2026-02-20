#!/usr/bin/env bash
# GOOD 'NUFF SHOP MANAGEMENT SETUP
# This script creates your Good'Nuff business tools and folder structure.

set -e

echo "=== GOOD 'NUFF SHOP SETUP START ==="

# 1) Core folders
BUS="$HOME/.business"
CUST_DIR="$BUS/customers"
JOBS_DIR="$BUS/jobs"
LOG_DIR="$BUS/.logs"
ARCHIVE_DIR="$BUS/archive"
OUTGOING="$HOME/Outgoing"
BIN="$HOME/.local/bin"

mkdir -p "$CUST_DIR" "$JOBS_DIR" "$LOG_DIR" "$ARCHIVE_DIR" "$OUTGOING" "$BIN"

# 2) Customer database CSV
CUST_DB="$CUST_DIR/customers.csv"
if [ ! -f "$CUST_DB" ]; then
  echo "customer_id,name,phone,email,vehicle,plate_or_vin,created_at" > "$CUST_DB"
  echo "Created customer DB at $CUST_DB"
else
  echo "Customer DB already exists at $CUST_DB"
fi

# 3) Jobs index CSV
JOBS_DB="$BUS/jobs.csv"
if [ ! -f "$JOBS_DB" ]; then
  echo "job_id,customer_id,customer_name,date,vehicle,job_desc,folder,mileage" > "$JOBS_DB"
  echo "Created jobs index at $JOBS_DB"
else
  echo "Jobs index already exists at $JOBS_DB"
fi

########################################
# Script: newjob
########################################
cat << 'EOF' > "$BIN/newjob"
#!/usr/bin/env bash
# Create a new customer job and folder structure

set -e
BASE="$HOME/.business"
CUST_DIR="$BASE/customers"
JOBS_DIR="$BASE/jobs"
CUST_DB="$CUST_DIR/customers.csv"
JOBS_DB="$BASE/jobs.csv"

mkdir -p "$CUST_DIR" "$JOBS_DIR"

echo "=== New Job ==="
read -rp "Customer full name: " cust_name
if [ -z "$cust_name" ]; then
  echo "Customer name is required."
  exit 1
fi

read -rp "Phone: " cust_phone
read -rp "Email: " cust_email
read -rp "Vehicle (year make model): " vehicle
read -rp "Plate or VIN (optional): " pov
read -rp "Mileage (optional): " mileage
read -rp "Short job description: " job_desc

cust_slug=$(echo "$cust_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/_\+/_/g; s/^_//; s/_$//')
[ -z "$cust_slug" ] && cust_slug="cust"

cust_id="$cust_slug"
created_at=$(date -Is)

# Ensure customer DB exists
if [ ! -f "$CUST_DB" ]; then
  echo "customer_id,name,phone,email,vehicle,plate_or_vin,created_at" > "$CUST_DB"
fi

# Add customer row if this ID is new
if ! grep -qi "^$cust_id," "$CUST_DB" 2>/dev/null; then
  printf '%s,"%s","%s","%s","%s","%s","%s"\n' \
    "$cust_id" "$cust_name" "$cust_phone" "$cust_email" "$vehicle" "$pov" "$created_at" >> "$CUST_DB"
fi

job_id=$(date +%Y%m%d_%H%M%S)
job_folder="${JOBS_DIR}/${cust_slug}_${job_id}"
mkdir -p "$job_folder"/{photos,diagnostics,docs,invoice}

job_date=$(date +%Y-%m-%d)

# Ensure jobs DB exists
if [ ! -f "$JOBS_DB" ]; then
  echo "job_id,customer_id,customer_name,date,vehicle,job_desc,folder,mileage" > "$JOBS_DB"
fi

printf '%s,%s,"%s",%s,"%s","%s","%s","%s"\n' \
  "$job_id" "$cust_id" "$cust_name" "$job_date" "$vehicle" "$job_desc" "$job_folder" "$mileage" >> "$JOBS_DB"

cat > "$job_folder/meta.txt" <<META
Customer: $cust_name
Phone: $cust_phone
Email: $cust_email
Vehicle: $vehicle
Plate/VIN: $pov
Mileage: $mileage
Job description: $job_desc
Job ID: $job_id
Job date: $job_date
Folder: $job_folder
META

touch "$job_folder/notes.txt"

echo
echo "Job created:"
echo "  ID:     $job_id"
echo "  Folder: $job_folder"
echo "Store photos in photos/, scanner exports in diagnostics/, and invoice files in invoice/."
EOF

########################################
# Script: addnote
########################################
cat << 'EOF' > "$BIN/addnote"
#!/usr/bin/env bash
# Add a timestamped note to a specific job

set -e
BASE="$HOME/.business"
JOBS_DIR="$BASE/jobs"

if [ ! -d "$JOBS_DIR" ]; then
  echo "No jobs directory found at $JOBS_DIR"
  exit 1
fi

echo "=== Add Job Note ==="
read -rp "Search jobs by customer/vehicle/keyword: " q
if [ -z "$q" ]; then
  echo "Search text is required."
  exit 1
fi

mapfile -t matches < <(find "$JOBS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' | grep -i "$q" | sort | tail -n 20)

if [ "${#matches[@]}" -eq 0 ]; then
  echo "No matching jobs found for '$q'."
  exit 1
fi

echo
echo "Matching jobs:"
for i in "${!matches[@]}"; do
  idx=$((i+1))
  echo "[$idx] ${matches[$i]}"
done
echo

read -rp "Select job number: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#matches[@]}" ]; then
  echo "Invalid selection."
  exit 1
fi

job_dir="${matches[$((choice-1))]}"
full_path="$JOBS_DIR/$job_dir"

echo
read -rp "Note text: " note
if [ -z "$note" ]; then
  echo "Empty note, nothing added."
  exit 0
fi

ts=$(date -Is)
echo "[$ts] $note" >> "$full_path/notes.txt"

echo "Note added to: $full_path/notes.txt"
EOF

########################################
# Script: diaglog
########################################
cat << 'EOF' > "$BIN/diaglog"
#!/usr/bin/env bash
# Create a diagnostic log (complaint/cause/correction + codes)

set -e
BASE="$HOME/.business"
JOBS_DIR="$BASE/jobs"

if [ ! -d "$JOBS_DIR" ]; then
  echo "No jobs directory found at $JOBS_DIR"
  exit 1
fi

echo "=== Diagnostic Log ==="
read -rp "Search jobs by customer/vehicle/keyword: " q
if [ -z "$q" ]; then
  echo "Search text is required."
  exit 1
fi

mapfile -t matches < <(find "$JOBS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' | grep -i "$q" | sort | tail -n 20)

if [ "${#matches[@]}" -eq 0 ]; then
  echo "No matching jobs found for '$q'."
  exit 1
fi

echo
echo "Matching jobs:"
for i in "${!matches[@]}"; do
  idx=$((i+1))
  echo "[$idx] ${matches[$i]}"
done
echo

read -rp "Select job number: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#matches[@]}" ]; then
  echo "Invalid selection."
  exit 1
fi

job_dir="${matches[$((choice-1))]}"
full_path="$JOBS_DIR/$job_dir"

echo
read -rp "Customer concern / complaint: " complaint
read -rp "Findings / cause: " cause
read -rp "Work performed / correction: " correction
read -rp "Codes (DTCs) if any: " codes
read -rp "Mileage at time of visit: " mileage
read -rp "Recommendations / future work: " recs

diag_file="$full_path/diagnostics/diag_$(date +%Y%m%d_%H%M%S).txt"

cat > "$diag_file" <<LOG
GOOD 'NUFF MOBILE MECHANIC - DIAGNOSTIC REPORT
Date: $(date)
Job folder: $full_path

Complaint:
$complaint

Cause / Findings:
$cause

Work Performed / Correction:
$correction

Diagnostic Trouble Codes:
$codes

Mileage:
$mileage

Recommendations:
$recs
LOG

echo
echo "Diagnostic log saved to:"
echo "  $diag_file"
EOF

########################################
# Script: vehiclehistory
########################################
cat << 'EOF' > "$BIN/vehiclehistory"
#!/usr/bin/env bash
# Show job history filtered by customer or vehicle from jobs.csv

set -e
BASE="$HOME/.business"
JOBS_DB="$BASE/jobs.csv"

if [ ! -f "$JOBS_DB" ]; then
  echo "No jobs.csv found at $JOBS_DB"
  exit 1
fi

echo "=== Vehicle / Customer History ==="
read -rp "Search by customer name, vehicle, or keyword: " q
if [ -z "$q" ]; then
  echo "Search text is required."
  exit 1
fi

echo
echo "Matches (date | customer | vehicle | job_desc | job_id):"
awk -F',' -v q="$(echo "$q" | tr '[:upper:]' '[:lower:]')" '
NR==1 { next }
{
  # columns: job_id,customer_id,customer_name,date,vehicle,job_desc,folder,mileage
  line = tolower($3 "," $5 "," $6);
  if (line ~ q) {
    printf "%s | %s | %s | %s | %s\n", $4, $3, $5, $6, $1;
  }
}
' "$JOBS_DB"
EOF

########################################
# Script: bizbackup
########################################
cat << 'EOF' > "$BIN/bizbackup"
#!/usr/bin/env bash
# Backup .business and Outgoing into a timestamped tar.gz

set -e
BUS="$HOME/.business"
OUTGOING="$HOME/Outgoing"
BACK_DIR="$HOME/.business_backups"

mkdir -p "$BACK_DIR"

ts=$(date +%Y%m%d_%H%M%S)
backup_file="$BACK_DIR/goodnuff_business_$ts.tar.gz"

echo "=== Business Backup ==="
echo "Creating backup..."
tar -czf "$backup_file" "$BUS" "$OUTGOING"

echo "Backup created:"
echo "  $backup_file"
EOF

########################################
# Script: gn (Good 'Nuff menu)
########################################
cat << 'EOF' > "$BIN/gn"
#!/usr/bin/env bash
# Good 'Nuff main business menu

while true; do
  clear
  echo "====================================="
  echo "   GOOD 'NUFF MOBILE MECHANIC - GN   "
  echo "====================================="
  echo "1) Create new job"
  echo "2) Add note to job"
  echo "3) Create diagnostic log"
  echo "4) View vehicle/customer history"
  echo "5) Run business backup"
  echo "6) Open Outgoing folder path"
  echo "7) Quit"
  echo "-------------------------------------"
  read -rp "Choose an option [1-7]: " choice

  case "$choice" in
    1) newjob; read -rp "Press Enter to continue..." _ ;;
    2) addnote; read -rp "Press Enter to continue..." _ ;;
    3) diaglog; read -rp "Press Enter to continue..." _ ;;
    4) vehiclehistory; read -rp "Press Enter to continue..." _ ;;
    5) bizbackup; read -rp "Press Enter to continue..." _ ;;
    6) echo "Your Outgoing folder is: $HOME/Outgoing"; read -rp "Press Enter to continue..." _ ;;
    7) echo "Goodbye."; exit 0 ;;
    *) echo "Invalid option."; sleep 1 ;;
  esac
done
EOF

# Make all scripts executable
chmod +x "$BIN/newjob" "$BIN/addnote" "$BIN/diaglog" "$BIN/vehiclehistory" "$BIN/bizbackup" "$BIN/gn"

# Add aliases to zshrc
ZSHRC="$HOME/.zshrc"
if ! grep -q "alias gn=" "$ZSHRC" 2>/dev/null; then
  {
    echo ""
    echo "# Good 'Nuff business aliases"
    echo "alias gn='$HOME/.local/bin/gn'"
    echo "alias newjob='$HOME/.local/bin/newjob'"
    echo "alias addnote='$HOME/.local/bin/addnote'"
    echo "alias diaglog='$HOME/.local/bin/diaglog'"
    echo "alias vehiclehistory='$HOME/.local/bin/vehiclehistory'"
    echo "alias bizbackup='$HOME/.local/bin/bizbackup'"
  } >> "$ZSHRC"
  echo "Added Good 'Nuff aliases to $ZSHRC"
else
  echo "Good 'Nuff aliases already present in $ZSHRC (or a similar line)."
fi

echo "=== GOOD 'NUFF SHOP SETUP DONE ==="
echo "Now run: source ~/.zshrc"
echo "Then type: gn"
EOF