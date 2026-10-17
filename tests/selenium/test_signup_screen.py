import os
import sys
import time
import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from flutter_helper import FlutterHelper


@pytest.mark.signup
class TestSignupScreen:
    """Selenium end-to-end test suite for the POS Podda Sign Up / Registration Screen."""

    @pytest.fixture(autouse=True)
    def navigate_to_signup(self, flutter: FlutterHelper):
        """Pre-condition: Navigate to the Signup Screen from Login."""
        flutter.click_button("Sign Up")
        time.sleep(1.0)
        assert flutter.is_text_visible("Start your journey", timeout=8), "Failed to navigate to Signup screen"

    def test_signup_screen_renders_all_fields(self, flutter: FlutterHelper):
        """Verifies that all registration fields and action buttons render on the Sign Up Screen."""
        # 1. Header & Description
        assert flutter.is_text_visible("Start your journey", timeout=5)
        assert flutter.is_text_visible("Create a free account to secure your data.", timeout=5)

        # 2. Form Inputs
        assert flutter.find_input("Full Name", timeout=8) is not None, "Full Name input field not found"
        assert flutter.find_input("Mobile Number", timeout=8) is not None, "Mobile Number input field not found"
        assert flutter.find_input("Email", timeout=8) is not None, "Email input field not found"
        assert flutter.find_input("Password", timeout=8) is not None, "Password input field not found"
        assert flutter.find_input("Confirm Password", timeout=8) is not None, "Confirm Password input field not found"

        # 3. Actions
        assert flutter.find_semantic("CREATE ACCOUNT", role="button", timeout=5) is not None
        assert flutter.find_semantic("Sign up with Google", timeout=5) is not None, "Sign up with Google button not found"
        assert flutter.find_semantic("Back to Login", timeout=5) is not None

    def test_signup_empty_form_validation(self, flutter: FlutterHelper):
        """Clicking 'CREATE ACCOUNT' with empty fields must trigger required field validation."""
        flutter.click_button("CREATE ACCOUNT")
        time.sleep(0.5)

        # Flutter validator catches empty required fields
        has_error = (
            flutter.wait_for_snackbar_or_dialog("Required", timeout=4)
            or flutter.wait_for_snackbar_or_dialog("Invalid Email", timeout=4)
            or flutter.wait_for_snackbar_or_dialog("Password too short", timeout=4)
        )
        assert has_error, "Form submission allowed with empty fields"

    def test_signup_password_too_short_validation(self, flutter: FlutterHelper):
        """Entering a password under 6 characters must trigger length validation."""
        flutter.type_into("Full Name", "Amal Perera")
        flutter.type_into("Mobile Number", "0771234567")
        flutter.type_into("Email", "amal@pospodda.app")
        flutter.type_into("Password", "12345")
        flutter.type_into("Confirm Password", "12345")

        flutter.click_button("CREATE ACCOUNT")
        time.sleep(0.5)

        assert flutter.wait_for_snackbar_or_dialog("Password too short", timeout=4), "Validation failed to enforce minimum password length"

    def test_signup_password_mismatch(self, flutter: FlutterHelper):
        """Entering non-matching passwords must display 'Passwords do not match!' notification."""
        flutter.type_into("Full Name", "Kamal Silva")
        flutter.type_into("Mobile Number", "0719876543")
        flutter.type_into("Email", "kamal@pospodda.app")
        flutter.type_into("Password", "securePassword123")
        flutter.type_into("Confirm Password", "differentPassword456")

        flutter.click_button("CREATE ACCOUNT")
        time.sleep(0.5)

        assert flutter.wait_for_snackbar_or_dialog("Passwords do not match!", timeout=5), "Password mismatch error not displayed"

    def test_signup_back_to_login_navigation(self, flutter: FlutterHelper):
        """Clicking 'Back to Login' returns the user back to the primary Login Screen."""
        flutter.click_button("Back to Login")
        time.sleep(1.0)

        # Verify returned to Login Screen
        assert flutter.is_text_visible("Login to your shop", timeout=8), "Failed to navigate back to Login Screen"
        assert flutter.find_semantic("LOGIN", role="button", timeout=5) is not None
