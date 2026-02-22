def vin_fetch_online(vin: str, year: str) -> dict | None:
    """Query NHTSA VPIC API for full VIN details."""
    import urllib.request, json

    url = (
        f"https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/"
        f"{vin}?format=json&modelyear={year}"
    )

    try:
        with urllib.request.urlopen(url, timeout=8) as r:
            data = json.loads(r.read().decode("utf-8"))
    except Exception:
        return None   # no internet / API error
    
    results = data.get("Results", [])
    if not results:
        return None
    
    r0 = results[0]
    return {
        "make": r0.get("Make") or "?",
        "model": r0.get("Model") or "?",
        "model_year": r0.get("ModelYear") or "?",
        "body_class": r0.get("BodyClass") or "?",
        "trim": r0.get("Trim") or "?",
        "engine": r0.get("EngineModel") or "?",
        "engine_disp": r0.get("DisplacementL") or "?",
        "cyl": r0.get("EngineCylinders") or "?",
        "fuel": r0.get("FuelTypePrimary") or "?",
    }