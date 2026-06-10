#!/usr/bin/env python3
"""Upload APK to Appwrite Storage and update version document for in-app update notifications.

This script is called from GitHub Actions after a successful release APK build.
It performs the following:
1. Uploads the APK to Appwrite Storage
2. Updates the version document in Appwrite Database
3. This triggers update notifications in the app via realtime subscription
"""

import hashlib
import json
import os
import sys
from pathlib import Path

import requests

# Environment variables (from GitHub Secrets)
APPWRITE_ENDPOINT = os.environ.get("APPWRITE_ENDPOINT")
APPWRITE_PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID")
APPWRITE_API_KEY = os.environ.get("APPWRITE_API_KEY")
APPWRITE_MAIN_ENDPOINT = os.environ.get("APPWRITE_MAIN_ENDPOINT", APPWRITE_ENDPOINT)
APPWRITE_MAIN_PROJECT_ID = os.environ.get("APPWRITE_MAIN_PROJECT_ID", APPWRITE_PROJECT_ID)
APPWRITE_MAIN_API_KEY = os.environ.get("APPWRITE_MAIN_API_KEY", APPWRITE_API_KEY)
APPWRITE_BUCKET_ID = os.environ.get("APPWRITE_BUCKET_ID")
APPWRITE_DATABASE_ID = os.environ.get("APPWRITE_DATABASE_ID")
APPWRITE_COLLECTION_ID = os.environ.get("APPWRITE_COLLECTION_ID")
APPWRITE_VERSION_DOC_ID = os.environ.get("APPWRITE_VERSION_DOC_ID")
APP_VERSION = os.environ.get("APP_VERSION")
APK_PATH = os.environ.get("APK_PATH")

# Required environment variables
REQUIRED_VARS = [
    "APPWRITE_ENDPOINT",
    "APPWRITE_PROJECT_ID",
    "APPWRITE_API_KEY",
    "APPWRITE_BUCKET_ID",
    "APPWRITE_DATABASE_ID",
    "APPWRITE_COLLECTION_ID",
    "APPWRITE_VERSION_DOC_ID",
    "APP_VERSION",
    "APK_PATH",
]


def log(message: str) -> None:
    """Print log message with timestamp."""
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


def validate_environment() -> bool:
    """Check if all required environment variables are set."""
    missing = []
    for var in REQUIRED_VARS:
        if not os.environ.get(var):
            missing.append(var)
    
    if missing:
        log(f"ERROR: Missing required environment variables: {', '.join(missing)}")
        return False
    
    if not Path(APK_PATH).exists():
        log(f"ERROR: APK file not found at {APK_PATH}")
        return False
    
    return True


def get_apk_info(apk_path: str) -> dict:
    """Get APK file information (size, SHA256 hash)."""
    path = Path(apk_path)
    size = path.stat().st_size
    
    # Calculate SHA256 hash
    sha256_hash = hashlib.sha256()
    with open(apk_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    
    return {
        "size": size,
        "size_mb": round(size / (1024 * 1024), 2),
        "sha256": sha256_hash.hexdigest(),
        "filename": path.name,
    }


def upload_to_appwrite_storage(
    apk_path: str,
    bucket_id: str,
    endpoint: str,
    project_id: str,
    api_key: str,
) -> dict:
    """Upload APK to Appwrite Storage."""
    log(f"Uploading APK to Appwrite Storage (bucket: {bucket_id})...")
    
    url = f"{endpoint}/storage/buckets/{bucket_id}/files"
    headers = {
        "X-Appwrite-Project": project_id,
        "X-Appwrite-Key": api_key,
    }
    
    apk_info = get_apk_info(apk_path)
    
    files = {
        "file": (apk_info["filename"], open(apk_path, "rb"), "application/vnd.android.package-archive"),
        "fileId": (None, f"lumio-apk-{APP_VERSION}"),
    }
    data = {
        "folderId": (None, ""),
    }
    
    try:
        response = requests.post(url, headers=headers, files=files, data=data, timeout=300)
        response.raise_for_status()
        
        result = response.json()
        file_id = result["$id"]
        download_url = f"{endpoint}/storage/buckets/{bucket_id}/files/{file_id}/view?project={project_id}"
        
        log(f"APK uploaded successfully: {file_id}")
        log(f"Download URL: {download_url}")
        log(f"Size: {apk_info['size_mb']} MB, SHA256: {apk_info['sha256'][:16]}...")
        
        return {
            "file_id": file_id,
            "download_url": download_url,
            "size": apk_info["size"],
            "sha256": apk_info["sha256"],
        }
    except requests.exceptions.RequestException as e:
        log(f"ERROR: Failed to upload APK to Appwrite Storage: {e}")
        raise


def update_version_document(
    database_id: str,
    collection_id: str,
    document_id: str,
    apk_info: dict,
    endpoint: str,
    project_id: str,
    api_key: str,
) -> bool:
    """Update version document in Appwrite Database."""
    log(f"Updating version document {document_id}...")
    
    url = f"{endpoint}/databases/{database_id}/collections/{collection_id}/documents/{document_id}"
    headers = {
        "X-Appwrite-Project": project_id,
        "X-Appwrite-Key": api_key,
        "Content-Type": "application/json",
    }
    
    # Parse version (e.g., "1.1.0" -> [1, 1, 0])
    version_parts = [int(x) for x in APP_VERSION.split("+")[0].split(".")]
    build_number = APP_VERSION.split("+")[1] if "+" in APP_VERSION else "0"
    
    document_data = {
        "version": APP_VERSION,
        "versionCode": int(build_number),
        "downloadUrl": apk_info["download_url"],
        "fileId": apk_info["file_id"],
        "size": apk_info["size"],
        "sha256": apk_info["sha256"],
        "releasedAt": int(Path(apk_path).stat().st_mtime * 1000),  # Unix timestamp in ms
        "major": version_parts[0] if len(version_parts) > 0 else 0,
        "minor": version_parts[1] if len(version_parts) > 1 else 0,
        "patch": version_parts[2] if len(version_parts) > 2 else 0,
    }
    
    try:
        response = requests.patch(url, headers=headers, json=document_data, timeout=30)
        response.raise_for_status()
        
        log(f"Version document updated successfully")
        log(f"Version: {APP_VERSION}, Download URL: {apk_info['download_url']}")
        
        return True
    except requests.exceptions.RequestException as e:
        log(f"ERROR: Failed to update version document: {e}")
        if hasattr(e, 'response') and e.response:
            log(f"Response: {e.response.text}")
        raise


def main() -> int:
    """Main function to orchestrate APK upload and version update."""
    log("=" * 60)
    log("Appwrite APK Publish Script")
    log(f"Version: {APP_VERSION}")
    log(f"APK Path: {APK_PATH}")
    log("=" * 60)
    
    if not validate_environment():
        return 1
    
    try:
        # Step 1: Upload APK to Storage
        apk_info = upload_to_appwrite_storage(
            apk_path=APK_PATH,
            bucket_id=APPWRITE_BUCKET_ID,
            endpoint=APPWRITE_MAIN_ENDPOINT or APPWRITE_ENDPOINT,
            project_id=APPWRITE_MAIN_PROJECT_ID or APPWRITE_PROJECT_ID,
            api_key=APPWRITE_MAIN_API_KEY or APPWRITE_API_KEY,
        )
        
        # Step 2: Update version document in Database
        update_version_document(
            database_id=APPWRITE_DATABASE_ID,
            collection_id=APPWRITE_COLLECTION_ID,
            document_id=APPWRITE_VERSION_DOC_ID,
            apk_info=apk_info,
            endpoint=APPWRITE_MAIN_ENDPOINT or APPWRITE_ENDPOINT,
            project_id=APPWRITE_MAIN_PROJECT_ID or APPWRITE_PROJECT_ID,
            api_key=APPWRITE_MAIN_API_KEY or APPWRITE_API_KEY,
        )
        
        log("=" * 60)
        log("✅ APK publish completed successfully!")
        log("Update notifications will be triggered in the app")
        log("=" * 60)
        
        return 0
        
    except Exception as e:
        log(f"ERROR: APK publish failed: {e}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
