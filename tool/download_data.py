"""Download all needed files from transfermarkt-datasets and Kaggle FIFA dataset."""
import urllib.request
import gzip
import shutil
import os
import zipfile

os.makedirs("data_sources", exist_ok=True)

CDN = "https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data"

# Transfermarkt files we need
tm_files = [
    "players.csv.gz",
    "appearances.csv.gz",
    "player_valuations.csv.gz",
    "transfers.csv.gz",
]

for fname in tm_files:
    url = f"{CDN}/{fname}"
    gz_path = f"data_sources/{fname}"
    csv_path = gz_path.replace(".gz", "")
    
    if os.path.exists(csv_path):
        size = os.path.getsize(csv_path) / (1024*1024)
        print(f"SKIP: {csv_path} already exists ({size:.1f} MB)")
        continue
    
    print(f"Downloading {fname}...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        resp = urllib.request.urlopen(req, timeout=60)
        with open(gz_path, "wb") as f:
            f.write(resp.read())
        
        # Decompress
        with gzip.open(gz_path, "rb") as f_in:
            with open(csv_path, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)
        
        size = os.path.getsize(csv_path) / (1024*1024)
        print(f"  OK: {csv_path} ({size:.1f} MB)")
        os.remove(gz_path)
    except Exception as e:
        print(f"  FAILED: {e}")

# FIFA/EA FC dataset from Kaggle
kaggle_url = "https://www.kaggle.com/api/v1/datasets/download/stefanoleone992/ea-sports-fc-24-complete-player-dataset"
zip_path = "data_sources/fc24.zip"
if not os.path.exists("data_sources/fc24_done"):
    print(f"Downloading EA FC 24 dataset from Kaggle...")
    try:
        req = urllib.request.Request(kaggle_url, headers={"User-Agent": "Mozilla/5.0"})
        resp = urllib.request.urlopen(req, timeout=120)
        with open(zip_path, "wb") as f:
            f.write(resp.read())
        size = os.path.getsize(zip_path) / (1024*1024)
        print(f"  Downloaded: {size:.1f} MB")
        
        # Extract
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall("data_sources/fc24")
            print(f"  Extracted: {z.namelist()}")
        
        # List extracted files
        for root, dirs, files in os.walk("data_sources/fc24"):
            for f in files:
                fp = os.path.join(root, f)
                size = os.path.getsize(fp) / (1024*1024)
                print(f"    {fp} ({size:.1f} MB)")
        
        open("data_sources/fc24_done", "w").close()
        os.remove(zip_path)
    except Exception as e:
        print(f"  FAILED: {e}")
else:
    print("SKIP: FC24 already downloaded")

print("\nDone!")
