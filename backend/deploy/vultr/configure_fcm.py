"""Firebase 서비스 계정 JSON을 기존 운영 환경 파일에 저장해요."""
import argparse
import json
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
from environment_settings import read_environment, save_settings


def configure_fcm(env_file: Path, service_account_json: Path, project_id: str):
    read_environment(env_file)
    account = json.loads(service_account_json.read_text(encoding='utf-8'))
    if account.get('type') != 'service_account' or account.get('project_id') != project_id:
        raise ValueError('앱과 같은 Firebase 프로젝트의 서비스 계정 파일을 사용해 주세요.')
    email, key = account['client_email'], account['private_key']
    if not email.endswith('.iam.gserviceaccount.com'):
        raise ValueError('서비스 계정 이메일을 확인해 주세요.')
    if not isinstance(serialization.load_pem_private_key(key.encode(), password=None), RSAPrivateKey):
        raise ValueError('RSA 서비스 계정 키를 사용해 주세요.')
    save_settings(env_file, {'FCM_PROJECT_ID': project_id, 'FCM_CLIENT_EMAIL': email,
                             'FCM_PRIVATE_KEY': key.replace('\n', '\\n')})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, required=True)
    parser.add_argument('--service-account-json', type=Path, required=True)
    parser.add_argument('--project-id', required=True)
    args = parser.parse_args()
    configure_fcm(args.env_file, args.service_account_json, args.project_id)
    print('FCM settings saved. Credentials are not printed.')


if __name__ == '__main__':
    main()
