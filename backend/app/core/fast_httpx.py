"""High-speed multi-threaded downloader using HTTPX for Dart SDK."""
import os
import sys
import time
import zipfile
import threading
import httpx

URL = "https://storage.googleapis.com/flutter_infra_release/flutter/5f77625673248ee5846fbcaf5d3e1a3878386fd7/dart-sdk-windows-x64.zip"
TARGET_DIR = r"E:\flutter_sdk\bin\cache"
ZIP_PATH = os.path.join(TARGET_DIR, "dart-sdk.zip")
NUM_THREADS = 16

def download_part(idx, start, end, part_path):
    headers = {"Range": f"bytes={start}-{end}"}
    with httpx.Client(timeout=60.0, follow_redirects=True) as client:
        resp = client.get(URL, headers=headers)
        if resp.status_code in [200, 206]:
            with open(part_path, "wb") as f:
                f.write(resp.content)
            print(f"[Part {idx}] Downloaded {len(resp.content)/(1024*1024):.2f} MB")
        else:
            print(f"[Part {idx}] Failed with status {resp.status_code}")

def parallel_download():
    os.makedirs(TARGET_DIR, exist_ok=True)
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        head_resp = client.head(URL)
        total_size = int(head_resp.headers["content-length"])
    print(f"Total archive size: {total_size / (1024*1024):.2f} MB. Spawning {NUM_THREADS} concurrent threads...")

    chunk_size = total_size // NUM_THREADS
    threads = []
    part_files = []
    start_time = time.time()

    for i in range(NUM_THREADS):
        start = i * chunk_size
        end = total_size - 1 if i == NUM_THREADS - 1 else (i + 1) * chunk_size - 1
        part_path = os.path.join(TARGET_DIR, f"part_{i}.bin")
        part_files.append(part_path)
        t = threading.Thread(target=download_part, args=(i, start, end, part_path))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    print(f"\nAll 16 parts downloaded in {time.time() - start_time:.2f}s! Assembling archive...")
    with open(ZIP_PATH, "wb") as out_f:
        for part_path in part_files:
            with open(part_path, "rb") as in_f:
                out_f.write(in_f.read())
            os.remove(part_path)

    print("Extracting Dart SDK to cache...")
    with zipfile.ZipFile(ZIP_PATH, "r") as zip_ref:
        zip_ref.extractall(TARGET_DIR)
    os.remove(ZIP_PATH)
    print("SUCCESS: Dart SDK is fully installed and extracted!")

if __name__ == "__main__":
    parallel_download()
