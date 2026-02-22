def vin_fetch_online(vin: str) -> dict | None:
    """Use NHTSA VPIC API to decode VIN online."""
    import urllib.request, json

    url = f"https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/{vin}?format=json"

    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
    except Exception:
        return None

    results = data.get("Results")
    if not results:
        return None

    r = results[0]

    return {
        "Make": r.get("Make") or "",
        "Model": r.get("Model") or "",
        "ModelYear": r.get("ModelYear") or "",
        "Trim": r.get("Trim") or "",
        "BodyClass": r.get("BodyClass") or "",
        "EngineCylinders": r.get("EngineCylinders") or "",
        "DisplacementL": r.get("DisplacementL") or "",
    }