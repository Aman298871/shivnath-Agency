import os

root_dir = r"d:\flutter\Shivnath project\shivnath_agency\lib\features\customer"

for dirpath, _, filenames in os.walk(root_dir):
    for f in filenames:
        if f.endswith(".dart"):
            p = os.path.join(dirpath, f)
            with open(p, "r", encoding="utf-8", errors="ignore") as file:
                lines = file.readlines()
                for idx, line in enumerate(lines):
                    if "outstanding" in line.lower() or "previous" in line.lower():
                        clean_line = line.strip().encode('ascii', 'replace').decode('ascii')
                        print(f"{f}:{idx+1}: {clean_line[:120]}")
