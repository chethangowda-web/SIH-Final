"""Multi-threaded fast downloader for Dart SDK."""
import os
import sys
import time
import zipfile
import threading
import urllib.request

URL = "https://storage.googleapis.com/flutter_infra_release/flutter/5f77625673248ee5846fbcaf5d3e1a3878386fd7/dart-sdk-windows-x64.zip"
TARGET_DIR = r"E:\flutter_sdk\bin\cache"
ZIP_PATH = os.path.join(TARGET_DIR, "dart-sdk.zip")
NUM_THREADS = 8

def download_chunk(start, end, part_path):
    req = urllib.request.Request(URL)
    req.headers['Range'] = f'bytes={start}-{end}'
    with urllib.request.urlopen(req, timeout=30) as resp, open(part_path, 'wb') as f:
        f.write(resp.read())

def fast_download():
    os.makedirs(TARGET_DIR, exist_ok=True)
    # Get total size
    req = urllib.request.Request(URL, method='HEAD')
    with urllib.request.urlopen(req, timeout=10) as resp:
        total_size = int(resp.headers['Content-Length'])
    print(f"Total size: {total_size / (1024*1024):.2f} MB, spawning {NUM_THREADS} threads...")

    chunk_size = total_size // NUM_THREADS
    threads = []
    part_files = []

    start_time = time.time()
    for i in range(NUM_THREADS):
        start = i * chunk_size
        end = total_size - 1 if i == NUM_THREADS - 1 else (i + 1) * chunk_size - 1
        part_path = os.path.join(TARGET_DIR, f"part_{i}.tmp")
        part_files.append(part_path)
        t = threading.Thread(target=download_chunk, args=(start, end, part_path))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    print(f"All chunks downloaded in {time.time() - start_time:.2f}s. Assembling...")
    with open(ZIP_PATH, 'wb') as out_f:
        for part_path in part_files:
            with open(part_path, 'rb') as in_f:
                out_f.write(in_f.read())
            os.remove(part_path)

    print("Extracting Dart SDK to cache...")
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(TARGET_DIR)
    os.remove(ZIP_PATH)
    print("Dart SDK successfully installed and extracted!")

if __name__ == "__main__":
    fast_download()
