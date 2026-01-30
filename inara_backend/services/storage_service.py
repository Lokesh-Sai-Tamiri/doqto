"""
Storage service for AWS S3 operations (presigned URLs, file management).
"""

from datetime import datetime, timezone
from typing import Optional, Tuple
import boto3
from botocore.exceptions import ClientError
import mimetypes
import uuid

from config import settings


class StorageService:
    """Service for S3 storage operations."""

    _client = None

    @classmethod
    def _get_client(cls):
        """Get or create S3 client."""
        if cls._client is None:
            cls._client = boto3.client(
                "s3",
                aws_access_key_id=settings.aws_access_key_id,
                aws_secret_access_key=settings.aws_secret_access_key,
                region_name=settings.aws_region,
            )
        return cls._client

    @staticmethod
    def _generate_key(user_id: str, filename: str, prefix: str = "") -> str:
        """Generate a unique S3 key for a file."""
        ext = filename.rsplit(".", 1)[-1] if "." in filename else ""
        unique_id = uuid.uuid4().hex[:12]
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d")

        if ext:
            return f"{prefix}{user_id}/{timestamp}_{unique_id}.{ext}"
        return f"{prefix}{user_id}/{timestamp}_{unique_id}"

    @classmethod
    def get_upload_url(
        cls,
        bucket: str,
        user_id: str,
        filename: str,
        content_type: Optional[str] = None,
        prefix: str = "",
    ) -> Tuple[str, str]:
        """
        Generate a presigned URL for uploading a file.

        Returns:
            Tuple of (presigned_url, object_key)
        """
        client = cls._get_client()

        # Generate unique key
        key = cls._generate_key(user_id, filename, prefix)

        # Determine content type
        if not content_type:
            content_type, _ = mimetypes.guess_type(filename)
            content_type = content_type or "application/octet-stream"

        try:
            presigned_url = client.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": bucket,
                    "Key": key,
                    "ContentType": content_type,
                },
                ExpiresIn=settings.s3_presigned_url_expiry,
            )

            return presigned_url, key

        except ClientError as e:
            raise Exception(f"Failed to generate upload URL: {str(e)}")

    @classmethod
    def get_download_url(cls, bucket: str, key: str) -> str:
        """Generate a presigned URL for downloading/viewing a file."""
        client = cls._get_client()

        try:
            presigned_url = client.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": bucket,
                    "Key": key,
                },
                ExpiresIn=settings.s3_presigned_url_expiry,
            )

            return presigned_url

        except ClientError as e:
            raise Exception(f"Failed to generate download URL: {str(e)}")

    @classmethod
    def get_public_url(cls, bucket: str, key: str) -> str:
        """Get the public URL for a file (if bucket has public access)."""
        return f"https://{bucket}.s3.{settings.aws_region}.amazonaws.com/{key}"

    @classmethod
    def delete_file(cls, bucket: str, key: str) -> bool:
        """Delete a file from S3."""
        client = cls._get_client()

        try:
            client.delete_object(Bucket=bucket, Key=key)
            return True
        except ClientError:
            return False

    # ==================== Avatar Operations ====================

    @classmethod
    def get_avatar_upload_url(cls, user_id: str, filename: str) -> Tuple[str, str, str]:
        """
        Get presigned URL for avatar upload.

        Returns:
            Tuple of (upload_url, object_key, final_url)
        """
        upload_url, key = cls.get_upload_url(
            bucket=settings.s3_bucket_avatars,
            user_id=user_id,
            filename=filename,
            prefix="avatars/",
        )

        # Generate final URL (assuming public read access on avatars bucket)
        final_url = cls.get_public_url(settings.s3_bucket_avatars, key)

        return upload_url, key, final_url

    # ==================== Attachment Operations ====================

    @classmethod
    def get_attachment_upload_url(
        cls,
        user_id: str,
        filename: str,
        content_type: Optional[str] = None,
    ) -> Tuple[str, str, str]:
        """
        Get presigned URL for message attachment upload.

        Returns:
            Tuple of (upload_url, object_key, download_url)
        """
        upload_url, key = cls.get_upload_url(
            bucket=settings.s3_bucket_attachments,
            user_id=user_id,
            filename=filename,
            content_type=content_type,
            prefix="attachments/",
        )

        # For attachments, use presigned download URL (private bucket)
        download_url = cls.get_download_url(settings.s3_bucket_attachments, key)

        return upload_url, key, download_url

    # ==================== Organization Logo Operations ====================

    @classmethod
    def get_org_logo_upload_url(cls, org_id: str, filename: str) -> Tuple[str, str, str]:
        """
        Get presigned URL for organization logo upload.

        Returns:
            Tuple of (upload_url, object_key, final_url)
        """
        upload_url, key = cls.get_upload_url(
            bucket=settings.s3_bucket_org_logos,
            user_id=org_id,  # Use org_id as user_id for path
            filename=filename,
            prefix="logos/",
        )

        # Generate final URL (assuming public read access on logos bucket)
        final_url = cls.get_public_url(settings.s3_bucket_org_logos, key)

        return upload_url, key, final_url


# Response models for upload URLs
class UploadUrlResponse:
    """Response containing presigned upload URL details."""

    def __init__(self, upload_url: str, key: str, final_url: str):
        self.upload_url = upload_url
        self.key = key
        self.final_url = final_url

    def to_dict(self) -> dict:
        return {
            "upload_url": self.upload_url,
            "key": self.key,
            "final_url": self.final_url,
        }
