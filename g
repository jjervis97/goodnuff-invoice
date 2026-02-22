def vin_clean(v: str) -> str:
    """Backwards-compatible wrapper"""
    return "".join(ch for ch in v.strip().upper() if not ch.isspace())