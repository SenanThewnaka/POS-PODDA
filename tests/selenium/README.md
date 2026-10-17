# POS Podda — Selenium Web Automated Test Suite

End-to-End (E2E) automated browser tests using **Python Selenium WebDriver** and **Pytest** specifically tailored for Flutter Web's CanvasKit and accessibility semantics rendering.

---

## 🎯 Test Coverage

### 1. Login Screen (`test_login_screen.py`)
* **Component Rendering**: Verifies app logo, brand title *"POS Podda"*, subtitle *"Login to your shop"*, Email & Password fields, action buttons (*LOGIN*, *Forgot Password?*, *Sign Up*, *LOGIN AS EMPLOYEE*).
* **Empty Form Validation**: Ensures submitting without inputs blocks submission and shows validation feedback.
* **Invalid Email Format**: Validates rejection of malformed email addresses (e.g. missing `@`).
* **Short Password**: Rejects passwords with length < 6 characters.
* **Forgot Password (Empty Email)**: Verifies prompt *"Enter Email first!"*.
* **Forgot Password (Invalid Email)**: Verifies format validation alert.
* **Forgot Password (Valid Email)**: Triggers Firebase reset email dispatch and checks confirmation message.
* **Navigation to Sign Up**: Verifies transition to registration screen.
* **Navigation to Employee Login**: Verifies staff access screen and interaction with the staff password reset guidance dialog.

### 2. Sign Up Screen (`test_signup_screen.py`)
* **Component Rendering**: Verifies registration header, *"Create a free account"*, inputs (*Full Name*, *Mobile Number*, *Email*, *Password*, *Confirm Password*), and action buttons (*CREATE ACCOUNT*, *Back to Login*).
* **Empty Form Validation**: Enforces mandatory fields before registration.
* **Short Password Validation**: Enforces minimum 6-character password constraint.
* **Password Mismatch Validation**: Enforces that *Password* and *Confirm Password* must match identically.
* **Back to Login Navigation**: Navigates back cleanly to the main login screen.

---

## 🛠️ Prerequisites

1. **Python 3.10+**
2. **Google Chrome** installed on your machine (ChromeDriver is managed automatically by Selenium Manager).
3. **Install Dependencies**:
   ```bash
   pip install -r tests/selenium/requirements.txt
   ```

---

## 🚀 How to Run the Tests

### Option A: Against Local Flutter Web Dev Server

1. Start your Flutter Web server on port `8080`:
   ```bash
   flutter run -d chrome --web-port 8080
   ```
2. In a separate terminal, run the tests:
   ```bash
   # Run all tests headlessly (fastest)
   python3 tests/selenium/run_selenium_tests.py --url http://localhost:8080

   # Run with visible browser window (watch tests interact live)
   python3 tests/selenium/run_selenium_tests.py --url http://localhost:8080 --headed
   ```

---

### Option B: Against Live Deployed App (`pospodda.app`)

You can run this test suite directly against your production or staging deployment:

```bash
# Headless test run against production
python3 tests/selenium/run_selenium_tests.py --url https://pospodda.app

# Interactive headed run
python3 tests/selenium/run_selenium_tests.py --url https://pospodda.app --headed
```

---

### Option C: Using `pytest` Directly

```bash
# Run only Login screen tests
pytest tests/selenium/test_login_screen.py --base-url https://pospodda.app -v

# Run only Signup screen tests
pytest tests/selenium/test_signup_screen.py --base-url https://pospodda.app -v

# Run with visible browser window
pytest tests/selenium/ --base-url https://pospodda.app --headed -v
```

---

## 📸 Failure Screenshots & Artifacts

If any test case fails, Selenium automatically captures a high-resolution screenshot of the browser state and saves it to:
```
tests/selenium/reports/screenshots/fail_<test_name>_<timestamp>.png
```
This allows instant visual debugging of UI anomalies or race conditions.
