"""실제 MMDB 형식과 요청 IP로 지역을 판별하고 외부 입력을 신뢰하지 않는지 확인해요."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from one_touch_loader.api.services import request_country

# MaxMind 공식 테스트 DB예요. 실제 운영 위치 데이터로 사용하지 않아요.
# 출처: maxmind/MaxMind-DB, b5f0b07f4dbea979821d55c61eef2700cfac4923 (MIT)
DATABASE = Path(__file__).parent / 'fixtures/geoip/GeoIP2-Country-Test.mmdb'


class RequestCountryTests(unittest.TestCase):
    def setUp(self):
        settings = patch.dict(os.environ, {'GEOIP_COUNTRY_DATABASE': str(DATABASE)})
        settings.start()
        self.addCleanup(settings.stop)

    def test_actual_database_ipv4_ipv6_and_mapped_ipv4(self):
        for address, country in [('81.2.69.160', 'GB'), ('2001:218::', 'JP'),
                                 ('2001:220::1', 'KR'), ('::ffff:81.2.69.160', 'GB')]:
            with self.subTest(address=address):
                self.assertEqual(request_country.country_for_ip(address), country)

    def test_uses_location_country_not_registered_country(self):
        # 이 테스트 IP의 소유자 등록 국가는 US지만 접속 국가는 GB예요.
        self.assertEqual(request_country.country_for_ip('81.2.69.160'), 'GB')

    def test_unknown_private_and_missing_addresses_have_no_default_country(self):
        for address in ['1.1.1.1', '127.0.0.1', '192.168.1.10', '::1', 'testclient', None]:
            with self.subTest(address=address):
                self.assertIsNone(request_country.country_for_ip(address))

    def test_database_replacement_is_read_on_the_next_request(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / 'country.mmdb'
            database.write_bytes(DATABASE.read_bytes())
            with patch.dict(os.environ, {'GEOIP_COUNTRY_DATABASE': str(database)}):
                self.assertEqual(request_country.country_for_ip('2001:220::1'), 'KR')
                database.write_bytes(b'invalid replacement')
                with self.assertLogs(request_country.logger, level='ERROR'), self.assertRaises(HTTPException) as failure:
                    request_country.country_for_ip('2001:220::1')
                self.assertEqual(failure.exception.status_code, 503)

    def test_missing_configuration_is_reported_instead_of_guessing(self):
        with patch.dict(os.environ, {'GEOIP_COUNTRY_DATABASE': ''}), self.assertRaises(HTTPException) as failure:
            request_country.country_for_ip('81.2.69.160')
        self.assertEqual(failure.exception.status_code, 503)

    def test_missing_database_reports_service_unavailable(self):
        with patch.dict(os.environ, {'GEOIP_COUNTRY_DATABASE': str(DATABASE) + '.missing'}), \
             self.assertLogs(request_country.logger, level='ERROR'), self.assertRaises(HTTPException) as failure:
            request_country.country_for_ip('81.2.69.160')
        self.assertEqual(failure.exception.status_code, 503)

    def test_country_headers_and_query_cannot_override_connection_ip(self):
        app = FastAPI()

        @app.get('/country')
        def country(value: str | None = Depends(request_country.get_request_country)):
            return {'country': value}

        with TestClient(app, client=('2001:220::1', 1234)) as client:
            response = client.get('/country?country_code=US&viewer_country=US', headers={
                'X-Forwarded-For': '81.2.69.160', 'CF-IPCountry': 'US', 'X-Country': 'US',
            })
        self.assertEqual(response.json(), {'country': 'KR'})
        self.assertEqual(response.headers['cache-control'], 'private, no-store')

    def test_only_a_trusted_proxy_can_supply_the_client_ip(self):
        app = FastAPI()
        app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=['127.0.0.1'])

        @app.get('/country')
        def country(value: str | None = Depends(request_country.get_request_country)):
            return {'country': value}

        for connection, expected in [('127.0.0.1', 'KR'), ('81.2.69.160', 'GB')]:
            with TestClient(app, client=(connection, 1234)) as client:
                response = client.get('/country', headers={'X-Forwarded-For': '2001:220::1'})
            self.assertEqual(response.json(), {'country': expected})


if __name__ == '__main__':
    unittest.main()
