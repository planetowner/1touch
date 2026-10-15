"""운영 DB 없이 실제 Connector 풀의 소진·반환과 공통 연결 대기를 검증해요."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from queue import Empty
from threading import Barrier, Event, Lock
from time import sleep
import unittest
from unittest.mock import Mock, patch

from mysql.connector import MySQLConnection, pooling
from mysql.connector.errors import InterfaceError, PoolError

with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.core import db


class DatabasePoolTests(unittest.TestCase):
    def setUp(self):
        # 연결 객체만 대체하고, 대여·반환은 운영과 같은 Connector 코드로 실행해요.
        self.pool = pooling.MySQLConnectionPool(pool_name="test", pool_size=5)
        self.pool.set_config(user="offline-test")
        for _ in range(self.pool.pool_size):
            connection = Mock(spec=MySQLConnection)
            connection.is_connected.return_value = True
            connection.pool_config_version = self.pool._config_version
            self.pool.add_connection(connection)
        patcher = patch.object(db, "_pool", self.pool)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_available_connection_keeps_native_return_behavior(self):
        with closing(db.get_conn()) as connection:
            self.assertIsInstance(connection, pooling.PooledMySQLConnection)
        held = [db.get_conn() for _ in range(5)]
        for connection in held:
            connection.close()

    def test_sixth_request_waits_until_a_connection_is_returned(self):
        held = [db.get_conn() for _ in range(5)]
        waiting = Event()

        def wait(seconds):
            waiting.set()
            sleep(seconds)

        try:
            with patch.object(db, "sleep", side_effect=wait), ThreadPoolExecutor(1) as workers:
                pending = workers.submit(db.get_conn)
                try:
                    self.assertTrue(waiting.wait(1), "Sixth request did not wait")
                    self.assertFalse(pending.done())
                finally:
                    held.pop().close()
                with closing(pending.result(timeout=2)):
                    pass
        finally:
            for connection in held:
                connection.close()

    def test_concurrent_burst_finishes_with_the_same_five_connections(self):
        ready = Barrier(20, timeout=3)
        lock = Lock()
        active = 0
        peak = 0

        def request(_):
            nonlocal active, peak
            ready.wait()
            with closing(db.get_conn()):
                with lock:
                    active += 1
                    peak = max(peak, active)
                try:
                    sleep(0.02)
                    return 1
                finally:
                    with lock:
                        active -= 1

        with ThreadPoolExecutor(20) as workers:
            self.assertEqual(sum(workers.map(request, range(20))), 20)
        self.assertLessEqual(peak, 5)
        self.assertEqual(active, 0)

    def test_pool_wait_expires_and_preserves_the_original_error(self):
        held = [db.get_conn() for _ in range(5)]
        try:
            with patch.object(db, "monotonic", side_effect=[10, 14.98, 15]), \
                    patch.object(db, "sleep") as wait:
                with self.assertRaises(PoolError) as error:
                    db.get_conn()
            self.assertIsInstance(error.exception.__cause__, Empty)
            self.assertIn("pool exhausted", str(error.exception))
            wait.assert_called_once()
            self.assertAlmostEqual(wait.call_args.args[0], 0.02)
        finally:
            for connection in held:
                connection.close()
        with closing(db.get_conn()):
            pass

    def test_other_connection_errors_are_not_retried(self):
        for failure in (InterfaceError("connection lost"), PoolError("invalid pool")):
            with self.subTest(error=type(failure).__name__), \
                    patch.object(self.pool, "get_connection", side_effect=failure) as acquire, \
                    patch.object(db, "sleep") as wait:
                with self.assertRaises(type(failure)) as error:
                    db.get_conn()
                self.assertIs(error.exception, failure)
                acquire.assert_called_once_with()
                wait.assert_not_called()

    def test_transaction_commits_or_rolls_back_once_and_returns_connection(self):
        for failure in (None, PoolError("query failed")):
            with self.subTest(failure=failure):
                calls = 0
                try:
                    with db.transaction() as connection:
                        raw_connection = connection._cnx
                        calls += 1
                        if failure is not None:
                            raise failure
                except PoolError as error:
                    self.assertIs(error, failure)
                self.assertEqual(calls, 1)
                if failure is None:
                    raw_connection.commit.assert_called_once_with()
                    raw_connection.rollback.assert_not_called()
                else:
                    raw_connection.rollback.assert_called_once_with()
                    raw_connection.commit.assert_not_called()
                raw_connection.reset_session.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
