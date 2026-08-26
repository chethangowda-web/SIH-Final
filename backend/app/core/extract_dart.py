"""Extract dart-sdk.zip into E:\flutter_sdk\bin\cache\dart-sdk."""
import os
import shutil
import zipfile

TARGET_DIR = r"E:\flutter_sdk\bin\cache"
ZIP_PATH = os.path.join(TARGET_DIR, "dart-sdk.zip")
EXTRACT_DIR = os.path.join(TARGET_DIR, "dart-sdk")

def extract():
    if not os.path.exists(ZIP_PATH):
        print(f"Error: {ZIP_PATH} does not exist.")
        return False

    size = os.path.getsize(ZIP_PATH)
    print(f"Found {ZIP_PATH} ({size / (1024*1024):.2f} MB). Extracting...")
    
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(TARGET_DIR)
    
    dart_bin = os.path.join(EXTRACT_DIR, "bin", "dart.exe")
    if os.path.exists(dart_bin):
        print(f"SUCCESS! Dart executable verified at: {dart_bin}")
        return True
    else:
        print(f"Warning: dart.exe not found at {dart_bin}")
        return False

if __name__ == "__main__":
    extract()
