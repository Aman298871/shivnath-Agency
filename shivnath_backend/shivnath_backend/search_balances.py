import os
import re

root_dir = r"d:\flutter\Shivnath project\shivnath_agency\lib"
patterns = [r"outstanding", r"previous_balance", r"balance", r"unpaid", r"47"]

matches = []
for dirpath, _, filenames in os.walk(root_dir):
    for f in filenames:
        if f.endswith(".dart"):
            p = os.path.join(dirpath, f)
            with open(p, "r", encoding="utf-8", errors="ignore") as file:
                lines = file.readlines()
                for idx, line in enumerate(lines):
                    if any(re.search(pat, line, re.IGNORECASE) for pat in patterns):
                        if any(term in line.lower() for term in ["outstanding", "balance", "previous"]):
                            matches.append(f"{f}:{idx+1}: {line.strip()[:100]}")

print(f"Total matches found: {len(matches)}")
for m in matches[:50]:
    print(m)
