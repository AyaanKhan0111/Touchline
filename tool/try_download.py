"""Try to download transfermarkt datasets from various URLs."""
import urllib.request
import os

urls = [
    ("GitHub data dir", "https://raw.githubusercontent.com/dcaribou/transfermarkt-datasets/refs/heads/master/data/players.csv.gz"),
    ("R2 CDN", "https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/players.csv.gz"),
]

for label, url in urls:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        resp = urllib.request.urlopen(req, timeout=10)
        size = resp.headers.get("Content-Length", "?")
        print(f"OK: {label} -> status {resp.status}, size {size}")
        # Save it
        with open("data_sources/players.csv.gz", "wb") as f:
            f.write(resp.read())
        print(f"  Saved to data_sources/players.csv.gz")
        break
    except Exception as e:
        print(f"FAIL: {label} -> {e}")

# Also try sofifa FIFA dataset
sofifa_urls = [
    ("Kaggle Stefano Leone FC24", "https://www.kaggle.com/api/v1/datasets/download/stefanoleone992/ea-sports-fc-24-complete-player-dataset"),
]
for label, url in sofifa_urls:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        resp = urllib.request.urlopen(req, timeout=10)
        print(f"OK: {label} -> status {resp.status}")
    except Exception as e:
        print(f"FAIL: {label} -> {e}")
