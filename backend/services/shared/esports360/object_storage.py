from __future__ import annotations

import time
from io import BytesIO
from urllib.parse import urlparse

from minio import Minio
from minio.error import S3Error

from .config import get_settings


def storage_driver() -> str:
    return get_settings().object_storage_driver.lower()


def using_minio() -> bool:
    return storage_driver() == "minio"


def _client() -> Minio:
    settings = get_settings()
    parsed = urlparse(settings.s3_endpoint)
    endpoint = parsed.netloc or parsed.path
    secure = settings.s3_secure or parsed.scheme == "https"
    return Minio(
        endpoint,
        access_key=settings.s3_access_key,
        secret_key=settings.s3_secret_key,
        secure=secure,
    )


def ensure_bucket(retries: int = 12, delay_seconds: float = 1.5) -> None:
    if not using_minio():
        return

    settings = get_settings()
    last_error: Exception | None = None
    for _ in range(retries):
        try:
            client = _client()
            if not client.bucket_exists(settings.s3_bucket):
                client.make_bucket(settings.s3_bucket)
            return
        except Exception as error:  # noqa: BLE001 - MinIO may still be starting.
            last_error = error
            time.sleep(delay_seconds)
    raise RuntimeError(f"MinIO bucket is not ready: {last_error}")


def put_object(storage_key: str, data: bytes, content_type: str = "application/octet-stream") -> None:
    settings = get_settings()
    ensure_bucket()
    _client().put_object(
        settings.s3_bucket,
        storage_key,
        BytesIO(data),
        length=len(data),
        content_type=content_type,
    )


def get_object_bytes(storage_key: str) -> tuple[bytes, str]:
    settings = get_settings()
    ensure_bucket()
    response = None
    try:
        response = _client().get_object(settings.s3_bucket, storage_key)
        content_type = response.headers.get("content-type", "application/octet-stream")
        return response.read(), content_type
    except S3Error as error:
        if error.code in {"NoSuchKey", "NoSuchObject"}:
            raise FileNotFoundError(storage_key) from error
        raise
    finally:
        if response is not None:
            response.close()
            response.release_conn()


def object_exists(storage_key: str) -> bool:
    settings = get_settings()
    ensure_bucket()
    try:
        _client().stat_object(settings.s3_bucket, storage_key)
        return True
    except S3Error as error:
        if error.code in {"NoSuchKey", "NoSuchObject"}:
            return False
        raise
