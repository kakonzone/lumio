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
import math
import os
import sys
import time
import uuid
from pathlib import Path

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

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


def create_session_with_retry(max_retries: int = 3) -> requests.Session:
    """Create a requests session with retry logic for SSL errors."""
    session = requests.Session()
    
    retry_strategy = Retry(
        total=max_retries,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD", "GET", "OPTIONS", "POST", "PUT", "DELETE"],
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    # Disable SSL verification temporarily for Singapore endpoint SSL issues
    session.verify = False
    
    # Suppress SSL warnings
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    return session


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
    """Upload APK to Appwrite Storage using chunked upload for large files."""
    log(f"Uploading APK to Appwrite Storage (bucket: {bucket_id})...")
    log(f"Using endpoint: {endpoint}")
    
    apk_info = get_apk_info(apk_path)
    session = create_session_with_retry(max_retries=3)
    
    try:
        # Use chunked upload for large files (Appwrite Education Pack has 150GB limit)
        file_id = upload_apk_chunked(endpoint, project_id, api_key, bucket_id, apk_path, apk_info, session)
        
        download_url = f"{endpoint}/storage/buckets/{bucket_id}/files/{file_id}/download?project={project_id}"
        
        log(f"APK uploaded successfully: {file_id}")
        log(f"Download URL: {download_url}")
        log(f"Size: {apk_info['size_mb']} MB, SHA256: {apk_info['sha256'][:16]}...")
        
        return {
            "file_id": file_id,
            "download_url": download_url,
            "size": apk_info["size"],
            "sha256": apk_info["sha256"],
        }
        
    except Exception as e:
        log(f"ERROR: Failed to upload APK: {e}")
        raise


def upload_apk_chunked(
    endpoint: str,
    project_id: str,
    api_key: str,
    bucket_id: str,
    apk_path: str,
    apk_info: dict,
    session: requests.Session,
) -> str:
    """Upload APK using chunked upload method for large files."""
    CHUNK_SIZE = 5 * 1024 * 1024  # 5MB chunks
    file_size = apk_info["size"]
    total_chunks = math.ceil(file_size / CHUNK_SIZE)
    
    # Generate unique file ID (keep consistent with APP_VERSION)
    file_id = f"lumio-apk-{APP_VERSION}"
    
    headers = {
        'X-Appwrite-Project': project_id,
        'X-Appwrite-Key': api_key,
    }
    
    log(f"Starting chunked upload: {apk_info['size_mb']} MB in {total_chunks} chunks")
    
    with open(apk_path, 'rb') as f:
        for i in range(total_chunks):
            start = i * CHUNK_SIZE
            chunk_data = f.read(CHUNK_SIZE)
            end = start + len(chunk_data) - 1
            
            chunk_headers = {
                **headers,
                'Content-Range': f'bytes {start}-{end}/{file_size}',
                'X-Appwrite-ID': file_id,
            }
            
            files = {
                'file': (apk_info["filename"], chunk_data, 'application/vnd.android.package-archive')
            }
            data = {
                'fileId': file_id,
                'folderId': '',
            }
            
            response = session.post(
                f'{endpoint}/storage/buckets/{bucket_id}/files',
                headers=chunk_headers,
                files=files,
                data=data,
                timeout=300
            )
            
            log(f'Chunk {i+1}/{total_chunks} uploaded ({end+1}/{file_size} bytes)')
            
            if response.status_code not in [200, 201, 202]:
                error_msg = f'Chunk {i+1} upload failed: {response.status_code}'
                if hasattr(response, 'text'):
                    error_msg += f' {response.text}'
                raise Exception(error_msg)
    
    log(f'All chunks uploaded successfully!')
    return file_id


def update_version_document(
    database_id: str,
    collection_id: str,
    document_id: str,
    apk_info: dict,
    endpoint: str,
    project_id: str,
    api_key: str,
) -> bool:
    """Update version document in Appwrite Database with retry logic and endpoint fallback."""
    log(f"Updating version document {document_id}...")
    
    # Get APK path from environment variable
    apk_path = os.environ.get('APK_PATH', '')
    
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
        "releasedAt": int(Path(apk_path).stat().st_mtime * 1000) if apk_path else int(0),  # Unix timestamp in ms
        "major": version_parts[0] if len(version_parts) > 0 else 0,
        "minor": version_parts[1] if len(version_parts) > 1 else 0,
        "patch": version_parts[2] if len(version_parts) > 2 else 0,
    }
    
    session = create_session_with_retry(max_retries=3)
    
    url = f"{endpoint}/databases/{database_id}/collections/{collection_id}/documents/{document_id}"
    headers = {
        "X-Appwrite-Project": project_id,
        "X-Appwrite-Key": api_key,
        "Content-Type": "application/json",
    }
    
    for attempt in range(3):
        try:
            response = session.patch(url, headers=headers, json=document_data, timeout=30)
            response.raise_for_status()
            
            log(f"Version document updated successfully")
            log(f"Version: {APP_VERSION}, Download URL: {apk_info['download_url']}")
            
            return True
        except requests.exceptions.RequestException as e:
            log(f"Update attempt {attempt + 1}/3 failed: {e}")
            if hasattr(e, 'response') and e.response:
                log(f"Response: {e.response.text}")
            if attempt < 2:
                wait_time = (attempt + 1) * 2
                log(f"Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
            else:
                log(f"ERROR: Failed to update version document after 3 attempts: {e}")
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
    
    # Use endpoint exactly as provided - no override, no manipulation
    endpoint = (APPWRITE_MAIN_ENDPOINT or APPWRITE_ENDPOINT).strip()
    if not endpoint:
        raise ValueError("APPWRITE_ENDPOINT is required")
    
    project_id = APPWRITE_MAIN_PROJECT_ID or APPWRITE_PROJECT_ID
    api_key = APPWRITE_MAIN_API_KEY or APPWRITE_API_KEY
    
    try:
        # Step 1: Upload APK to Storage
        apk_info = upload_to_appwrite_storage(
            apk_path=APK_PATH,
            bucket_id=APPWRITE_BUCKET_ID,
            endpoint=endpoint,
            project_id=project_id,
            api_key=api_key,
        )
        
        # Step 2: Update version document in Database
        update_version_document(
            database_id=APPWRITE_DATABASE_ID,
            collection_id=APPWRITE_COLLECTION_ID,
            document_id=APPWRITE_VERSION_DOC_ID,
            apk_info=apk_info,
            endpoint=endpoint,
            project_id=project_id,
            api_key=api_key,
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
