import os
import pytest

@pytest.fixture(scope="session", autouse=True)
def set_env_vars():
    """Enable auth mock by default for all test runs to preserve existing tests."""
    os.environ["PDS_TEST_AUTH_MOCK"] = "1"
