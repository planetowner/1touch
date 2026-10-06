"""운영 DB 대신 임시 백업 파일로 보관기한과 삭제 범위를 확인해요."""
import gzip
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


BACKUP_SCRIPT = Path(__file__).resolve().parents[2] / 'deploy/vultr/backup-db.sh'


class BackupRetentionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copyfile(BACKUP_SCRIPT, self.root / 'backup-db.sh')
        mock_bin = self.root / 'bin'
        mock_bin.mkdir()
        docker = mock_bin / 'docker'
        # 실제 Docker나 DB에 접근하지 않고 백업 성공·실패만 재현해요.
        docker.write_text('#!/bin/sh\nprintf "test database dump\\n"\nexit "${BACKUP_TEST_EXIT:-0}"\n')
        docker.chmod(0o700)
        self.environment = {**os.environ, 'PATH': f'{mock_bin}{os.pathsep}{os.environ["PATH"]}',
                            'BACKUP_TEST_EXIT': '0'}

    def old_file(self, relative, age_days):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('test backup')
        modified = time.time() - age_days * 86400
        os.utime(path, (modified, modified))
        return path

    def run_backup(self, *arguments):
        return subprocess.run(['bash', str(self.root / 'backup-db.sh'), *arguments],
                              env=self.environment, capture_output=True, text=True)

    def test_daily_run_prunes_both_retention_classes_and_preserves_other_files(self):
        expired = [self.old_file('backups/daily/20240101T000000Z.sql.gz', 14.1),
                   self.old_file('backups/20240101T000000Z.sql.gz', 30.1)]
        kept = [self.old_file('backups/daily/20240102T000000Z.sql.gz', 13.9),
                self.old_file('backups/20240102T000000Z.sql.gz', 29.9),
                self.old_file('backups/database.sql.gz', 60),
                self.old_file('backups/20240103T000000Z.sql.gz.partial', 60),
                self.old_file('backups/other/20240101T000000Z.sql.gz', 60)]
        result = self.run_backup('--daily')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(not path.exists() for path in expired))
        self.assertTrue(all(path.exists() for path in kept))

    def test_manual_backup_works_without_daily_directory(self):
        old = self.old_file('backups/20240101T000000Z.sql.gz', 30.1)
        result = self.run_backup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(old.exists())
        created = list((self.root / 'backups').glob('*.sql.gz'))
        self.assertEqual(len(created), 1)
        self.assertEqual(gzip.decompress(created[0].read_bytes()), b'test database dump\n')

    def test_failed_dump_preserves_existing_backups(self):
        old = [self.old_file('backups/daily/20240101T000000Z.sql.gz', 60),
               self.old_file('backups/20240101T000000Z.sql.gz', 60)]
        self.environment['BACKUP_TEST_EXIT'] = '1'
        result = self.run_backup('--daily')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(all(path.exists() for path in old))
        self.assertEqual(list(self.root.rglob('*.partial')), [])


if __name__ == '__main__':
    unittest.main()
