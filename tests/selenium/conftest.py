import os
import sys
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from flutter_helper import FlutterHelper


def pytest_addoption(parser):
    parser.addoption(
        "--base-url",
        action="store",
        default=os.environ.get("POS_BASE_URL", "http://localhost:8080"),
        help="Target base URL of the POS Podda Flutter Web application (e.g. http://localhost:8080 or https://pospodda.app)",
    )
    parser.addoption(
        "--headed",
        action="store_true",
        default=False,
        help="Run browser in visible mode (default is headless)",
    )


@pytest.fixture(scope="session")
def base_url(request):
    url = request.config.getoption("--base-url").rstrip("/")
    return url


@pytest.fixture(scope="function")
def driver(request):
    is_headed = request.config.getoption("--headed")

    options = Options()
    if not is_headed:
        options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1280,900")
    options.add_argument("--enable-accessibility")
    options.add_argument("--force-renderer-accessibility")

    driver = webdriver.Chrome(options=options)
    driver.set_page_load_timeout(30)
    driver.implicitly_wait(0)

    yield driver

    # Take screenshot if test failed
    if hasattr(request.node, "rep_call") and request.node.rep_call.failed:
        helper = FlutterHelper(driver)
        screenshot_path = helper.take_screenshot(f"fail_{request.node.name}")
        print(f"\n[FAILURE SCREENSHOT] Saved to: {screenshot_path}")

    driver.quit()


@pytest.fixture(scope="function")
def flutter(driver, base_url):
    driver.get(base_url)
    helper = FlutterHelper(driver, default_timeout=20)
    ready = helper.wait_for_flutter_app()
    if not ready:
        pytest.fail(f"Flutter application failed to load at {base_url}")
    return helper


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    # Hook to record test failure state on the test node
    outcome = yield
    rep = outcome.get_result()
    setattr(item, f"rep_{rep.when}", rep)
