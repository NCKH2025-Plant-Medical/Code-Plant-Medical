import unittest
from types import SimpleNamespace
from unittest.mock import patch
from API.user_plants import cloudinary_utils as storage


class CloudinaryConfigTests(unittest.TestCase):
    def test_credentials_are_read_at_use_time(self):
        with patch.dict(storage.os.environ, {
            'CLOUDINARY_CLOUD_NAME': 'test-cloud',
            'CLOUDINARY_API_KEY': 'test-key',
            'CLOUDINARY_API_SECRET': 'test-secret',
        }, clear=True), patch.object(storage.cloudinary, 'config', return_value=SimpleNamespace(
            cloud_name='test-cloud', api_key='test-key', api_secret='test-secret'
        )) as configure:
            storage._configure_cloudinary()
            configure.assert_called_once_with(secure=True, cloud_name='test-cloud',
                                              api_key='test-key', api_secret='test-secret')

    def test_sdk_url_configuration_is_not_overwritten_with_none(self):
        with patch.dict(storage.os.environ, {}, clear=True), patch.object(
            storage.cloudinary, 'config', return_value=SimpleNamespace(
                cloud_name='url-cloud', api_key='url-key', api_secret='url-secret'
            )
        ) as configure:
            storage._configure_cloudinary()
            configure.assert_called_once_with(secure=True)

    def test_missing_credentials_stop_before_upload(self):
        with patch.object(storage.cloudinary, 'config', return_value=SimpleNamespace(
            cloud_name='test-cloud', api_key=None, api_secret=None
        )), patch.object(storage.cloudinary.uploader, 'upload') as upload:
            with self.assertRaisesRegex(RuntimeError, 'CLOUDINARY_API_KEY'):
                storage.upload_plant_image(b'image', 'test-user')
            upload.assert_not_called()


if __name__ == '__main__':
    unittest.main()
