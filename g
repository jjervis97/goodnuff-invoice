# --- VIN TOOLS -------------------------------------------------------------

# Very small WMI table for common makes.
VIN_WMI: dict[str, str] = {
    # GM
    "1G1": "Chevrolet (USA)",
    "1G2": "Pontiac (USA)",
    "1G3": "Oldsmobile (USA)",
    "1G4": "Buick (USA)",
    "1G6": "Cadillac (USA)",
    "1GT": "GMC Truck (USA)",
    "2G1": "Chevrolet (Canada)",
    "3G1": "Chevrolet (Mexico)",
    # Ford
    "1FA": "Ford (USA)",
    "1FB": "Ford (USA)",
    "1FJ": "Ford (USA)",
    "1FT": "Ford Truck (USA)",
    "2FA": "Ford (Canada)",
    # Chrysler / Dodge / Jeep / Ram
    "1C3": "Chrysler (USA)",
    "1C4": "Chrysler SUV (USA)",
    "1C6": "Dodge Truck (USA)",
    "1D3": "Dodge Truck (USA)",
    "1J4": "Jeep (USA)",
    "1J8": "Jeep SUV (USA)",
    "3D7": "Ram Truck (Mexico)",
    # Toyota
    "1NX": "Toyota (USA)",
    "2T1": "Toyota (Canada)",
    "JTD": "Toyota (Japan)",
    "JTM": "Toyota SUV (Japan)",
    # Honda
    "1HG": "Honda (USA)",
    "2HG": "Honda (Canada)",
    "JHM": "Honda (Japan)",
    # Subaru
    "JF1": "Subaru (Japan)",
    "JF2": "Subaru SUV (Japan)",
    "4S3": "Subaru (USA)",
    "4S4": "Subaru SUV (USA)",
    # Hyundai / Kia (example)
    "5NP": "Hyundai (USA)",
    "5XX": "Kia (USA)",
    "KMH": "Hyundai (Korea)",
    "KNA": "Kia (Korea)",
}

# Basic country decode by first character.
VIN_COUNTRY: dict[str, str] = {
    "1": "USA",
    "2": "Canada",
    "3": "Mexico",
    "4": "USA",
    "5": "USA",
    "J": "Japan",
    "K": "Korea",
    "S": "UK",
    "V": "France / Spain",
    "W": "Germany",
    "Y": "Scandinavia",
    "Z": "Italy",
}


def vin_year_from_char(code: str) -> str:
    """Rough decode of model year from the 10th VIN character."""
    code = code.upper()
    year_map = {
        "A": 2010, "B": 2011, "C": 2012, "D": 2013, "E": 2014,
        "F": 2015, "G": 2016, "H": 2017, "J": 2018, "K": 2019,
        "L": 2020, "M": 2021, "N": 2022, "P": 2023, "R": 2024,
        "S": 2025, "T": 2026, "V": 2027, "W": 2028, "X": 2029,
        "Y": 2030,
        "1": 2001, "2": 2002, "3": 2003, "4": 2004, "5": 2005,
        "6": 2006, "7": 2007, "8": 2008, "9": 2009,
    }
    return str(year_map.get(code, "Unknown"))


def vin_decode_local(vin: str) -> dict[str, str]:
    """Offline decode – basic country, make, year, plant, serial."""
    v = vin.strip().upper()

    if len(v) != 17:
        return {"vin": v, "error": f"VIN must be 17 chars (got {len(v)})"}

    country = VIN_COUNTRY.get(v[0], "Unknown / other")
    wmi = v[:3]
    make = VIN_WMI.get(wmi, "Unknown manufacturer")
    year_code = v[9]
    model_year = vin_year_from_char(year_code)
    plant = v[10]
    serial = v[11:]
    check_digit = v[8]

    return {
        "vin": v,
        "country": country,
        "make": make,
        "model_year": model_year,
        "plant": plant,
        "serial": serial,
        "check_digit": check_digit,
    }


def vin_open_full_in_browser(vin: str) -> None:
    """Open the official NHTSA VIN decoder for this VIN."""
    url = f"https://vpic.nhtsa.dot.gov/decoder/Decoder?VIN={vin}&ModelYear="
    webbrowser.open(url)


def run_vin_tools() -> None:
    """VIN QUICK DECODE: offline summary + optional online open."""
    os.system("clear")
    gn_header("VIN QUICK DECODE")

    vin = input("\nEnter VIN (blank to cancel): ").strip()
    if not vin:
        return

    info = vin_decode_local(vin)

    os.system("clear")
    gn_header("VIN QUICK DECODE")

    if "error" in info:
        print(f"\nError: {info['error']}")
        pause()
        return

    print()
    print("Local decode (offline):")
    print("-" * 72)
    print(f"{'VIN':12}: {info['vin']}")
    print(f"{'Country':12}: {info['country']}")
    print(f"{'Manufacturer':12}: {info['make']}")
    print(f"{'Model year':12}: {info['model_year']}")
    print(f"{'Plant code':12}: {info['plant']}")
    print(f"{'Serial':12}: {info['serial']}")
    print(f"{'Check digit':12}: {info['check_digit']}")
    print("-" * 72)

    choice = input(
        "\nOpen full online decode at NHTSA in your browser? [Y/N]: "
    ).strip().lower()

    if choice == "y":
        vin_open_full_in_browser(info["vin"])
        input("\nOpened in browser (when you have internet). Press Enter to return...")