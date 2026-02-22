# 1) Run the API request
online_info = vin_fetch_online(vin)

# 2) Offer optional full-browser opening AFTER successful fetch
open_full = input("\nOpen full NHTSA decode in browser? [y/N]: ").strip().lower()
if open_full == "y":
    vin_open_full_in_browser(vin)

# 3) Handle failure
if online_info is None:
    print("\nOnline decode failed (no internet or API problem).")
else:
    print("\nOnline decode (NHTSA):")
    print("-" * 60)
    print(f"Make / Model : {online_info.get('Make','?')}  {online_info.get('Model','?')}")
    print(f"Year         : {online_info.get('ModelYear','?')}")
    print(f"Body / Trim  : {online_info.get('BodyClass','?')}")
    cyl = online_info.get('EngineCylinders') or "?"
    disp = online_info.get('EngineDisplacement') or "?"
    print(f"Engine       : {cyl} cyl, {disp} L")
    print("-" * 60)