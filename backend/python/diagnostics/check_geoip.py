"""API와 같은 사용자·경로로 국가 DB를 읽을 수 있는지 확인해요. 데이터는 바꾸지 않아요."""
import os

import maxminddb


def main():
    with maxminddb.open_database(os.environ['GEOIP_COUNTRY_DATABASE']) as database:
        metadata = database.metadata()
        if metadata.database_type != 'GeoLite2-Country' or metadata.ip_version != 6:
            raise SystemExit('GeoLite2-Country with IPv4/IPv6 support is required.')
        print(f'GeoIP database readable: {metadata.database_type}, build_epoch={metadata.build_epoch}')


if __name__ == '__main__':
    main()
