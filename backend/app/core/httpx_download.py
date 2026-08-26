"""Stream downloader using HTTPX for Dart SDK."""
import os
import sys
import zipfile
import httpx

URL = "https://storage.googleapis.com/flutter_infra_release/flutter/5f77625673248ee5846fbcaf5d3e1a3878386fd7/dart-sdk-windows-x64.zip"
TARGET_DIR = r"E:\flutter_sdk\bin\cache"
ZIP_PATH = os.path.join(TARGET_DIR, "dart-sdk.zip")

def download_and_extract():
    os.makedirs(TARGET_DIR, exist_ok=True)
    print("Starting download with httpx stream...")
    with httpx.Client(timeout=120.0, follow_redirects=True) as client:
        with client.stream("GET", URL) as response:
            total = int(response.headers.get("content-length", 0))
            print(f"Total size: {total / (1024*1024):.2f} MB")
            downloaded = 0
            with open(ZIP_PATH, "wb") as f:
                for chunk in response.iter_bytes(chunk_size=1024*1024): # 1MB chunks
                    f.write(chunk)
                    downloaded += len(chunk)
                    print(f"\rProgress: {downloaded / (1024*1024):.1f} / {total / (1024*1024):.1f} MB ({(downloaded/total)*100:.1f}%)", end="", flush=True)

    print("\nDownload complete! Extracting...")
    with zipfile.ZipFile(ZIP_PATH, "r") as zip_ref:
        zip_ref.extractall(TARGET_DIR)
    os.remove(ZIP_PATH)
    print("Dart SDK successfully extracted!")

if __name__ == "__main__":
    download_and_extract()
