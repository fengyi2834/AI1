import argparse
import datetime as dt
import hashlib
import hmac
import mimetypes
import os
import sys
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def load_env_map(path: Path) -> dict[str, str]:
    env_map: dict[str, str] = {}
    if not path.exists():
        return env_map

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env_map[key.strip()] = value.strip()
    return env_map


def build_signature_headers(
    *,
    method: str,
    endpoint: str,
    bucket: str,
    object_key: str,
    access_key: str,
    secret_key: str,
    region: str,
    body: bytes,
    content_type: str,
) -> tuple[str, dict[str, str]]:
    parsed = urllib.parse.urlparse(endpoint)
    host = parsed.netloc
    encoded_key = urllib.parse.quote(object_key, safe="/-_.~")
    canonical_uri = f"/{bucket}/{encoded_key}"
    amz_date = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    date_stamp = amz_date[:8]
    payload_hash = sha256_hex(body)

    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = (
        f"{method}\n"
        f"{canonical_uri}\n"
        f"\n"
        f"{canonical_headers}\n"
        f"{signed_headers}\n"
        f"{payload_hash}"
    )
    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = f"{date_stamp}/{region}/s3/aws4_request"
    string_to_sign = (
        f"{algorithm}\n"
        f"{amz_date}\n"
        f"{credential_scope}\n"
        f"{sha256_hex(canonical_request.encode('utf-8'))}"
    )

    k_date = sign(("AWS4" + secret_key).encode("utf-8"), date_stamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, "s3")
    k_signing = sign(k_service, "aws4_request")
    signature = hmac.new(k_signing, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    authorization = (
        f"{algorithm} Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    upload_url = f"{endpoint.rstrip('/')}/{bucket}/{encoded_key}"
    headers = {
        "Authorization": authorization,
        "x-amz-date": amz_date,
        "x-amz-content-sha256": payload_hash,
        "Content-Type": content_type,
        "Content-Length": str(len(body)),
    }
    return upload_url, headers


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload a file to the local FastGPT public MinIO bucket.")
    parser.add_argument("file", help="Path to the local file to upload")
    parser.add_argument("--env-file", default=r"C:\Users\Administrator\Desktop\AI1\infra\fastgpt\.env.local")
    parser.add_argument("--prefix", default="demo-images")
    parser.add_argument("--object-name", default="")
    args = parser.parse_args()

    file_path = Path(args.file)
    if not file_path.exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        return 1

    env_map = load_env_map(Path(args.env_file))
    endpoint = env_map.get("STORAGE_EXTERNAL_ENDPOINT") or "http://127.0.0.1:9100"
    bucket = env_map.get("STORAGE_PUBLIC_BUCKET") or "fastgpt-public"
    access_key = env_map.get("MINIO_ROOT_USER") or "minioadmin"
    secret_key = env_map.get("MINIO_ROOT_PASSWORD") or "minioadmin"
    region = env_map.get("STORAGE_REGION") or "us-east-1"

    body = file_path.read_bytes()
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    object_name = args.object_name.strip() or f"{args.prefix.strip('/')}/{uuid.uuid4().hex}_{file_path.name}"

    upload_url, headers = build_signature_headers(
        method="PUT",
        endpoint=endpoint,
        bucket=bucket,
        object_key=object_name,
        access_key=access_key,
        secret_key=secret_key,
        region=region,
        body=body,
        content_type=content_type,
    )

    request = urllib.request.Request(upload_url, data=body, method="PUT", headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status not in (200, 201):
            raise RuntimeError(f"Upload failed with status {response.status}")

    print(upload_url)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
