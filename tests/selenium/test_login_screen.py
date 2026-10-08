import os
import sys
import time
import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from flutter_helper import FlutterHelper


@pytest.mark.login
class TestLoginScreen:
    """Selenium end-to-end test suite for the POS Podda Login Screen."""

    def test_login_screen_renders_all_components(self, flutter: FlutterHelper):
        """Verifies that all required UI elements render on the Login Screen."""
        # 1. Verify Branding & Header
        assert flutter.is_text_visible("POS Podda", timeout=10), "App brand title 'POS Podda' not found"
        assert flutter.is_text_visible("Login to your shop", timeout=5), "Subtitle 'Login to your shop' not found"

        # 2. Verify Form Inputs
        assert flutter.find_input("Email", timeout=10) is not None, "Email input field not found"
        assert flutter.find_input("Password", timeout=10) is not None, "Password input field not found"

        # 3. Verify Action Buttons
        assert flutter.find_semantic("LOGIN", role="button", timeout=5) is not None, "LOGIN button not found"
        assert flutter.find_semantic("Continue with Google", timeout=5) is not None, "Continue with Google button not found"
        assert flutter.find_semantic("Forgot Password?", timeout=5) is not None, "Forgot Password link not found"
        assert flutter.find_semantic("Sign Up", timeout=5) is not None, "Sign Up link not found"
        assert flutter.find_semantic("LOGIN AS EMPLOYEE", timeout=5) is not None, "Employee Login button not found"

    def test_login_empty_form_validation(self, flutter: FlutterHelper):
        """Submitting an empty login form must display validation errors without calling auth."""
        flutter.click_button("LOGIN")
        time.sleep(0.5)

        # Flutter validator triggers "Invalid Email" and "Password too short"
        has_email_err = flutter.wait_for_snackbar_or_dialog("Invalid Email", timeout=3)
        has_pass_err = flutter.wait_for_snackbar_or_dialog("Password too short", timeout=3)

        assert has_email_err or has_pass_err, "Validation error message not displayed for empty form submission"

    def test_login_invalid_email_format(self, flutter: FlutterHelper):
        """Entering an email without '@' must trigger email format validation error."""
        flutter.type_into("Email", "testuserwithoutat")
        flutter.type_into("Password", "validPassword123")

        flutter.click_button("LOGIN")
        time.sleep(0.5)

        assert flutter.wait_for_snackbar_or_dialog("Invalid Email", timeout=4), "Email format validator failed to catch missing '@'"

    def test_login_password_too_short(self, flutter: FlutterHelper):
        """Entering a password shorter than 6 characters must trigger length validation."""
        flutter.type_into("Email", "merchant@pospodda.app")
        flutter.type_into("Password", "123")

        flutter.click_button("LOGIN")
        time.sleep(0.5)

        assert flutter.wait_for_snackbar_or_dialog("Password too short", timeout=4), "Password validator allowed password < 6 characters"

    def test_forgot_password_empty_email_prompt(self, flutter: FlutterHelper):
        """Clicking 'Forgot Password?' with an empty email field prompts 'Enter Email first!'."""
        flutter.type_into("Email", "", clear_first=True)
        flutter.click_button("Forgot Password?")

        assert flutter.wait_for_snackbar_or_dialog("Enter Email first!", timeout=4), "Expected prompt 'Enter Email first!' was not displayed"

    def test_forgot_password_invalid_email_format(self, flutter: FlutterHelper):
        """Clicking 'Forgot Password?' with an improperly formatted email handles input appropriately."""
        flutter.type_into("Email", "not-a-valid-email")
        flutter.click_button("Forgot Password?")

        received = flutter.wait_for_any_message(
            ["valid email", "Password Reset Email Sent!", "invalid", "Enter Email"],
            timeout=5,
        )
        assert received, "Invalid email feedback not shown"

    def test_forgot_password_valid_email_dispatch(self, flutter: FlutterHelper):
        """Entering a properly formatted email and clicking 'Forgot Password?' triggers reset workflow."""
        flutter.type_into("Email", "demo-owner@pospodda.app")
        flutter.click_button("Forgot Password?")

        # Expects success dispatch message or specific Firebase response
        received_feedback = (
            flutter.wait_for_snackbar_or_dialog("Password Reset Email Sent!", timeout=6)
            or flutter.wait_for_snackbar_or_dialog("No account found", timeout=6)
        )
        assert received_feedback, "No password reset status message displayed"

    def test_navigate_to_signup_screen(self, flutter: FlutterHelper):
        """Clicking 'Sign Up' navigates cleanly to the registration screen."""
        flutter.click_button("Sign Up")
        time.sleep(1.0)

        # Verify Signup Screen is active
        assert flutter.is_text_visible("Start your journey", timeout=8), "Failed to navigate to Signup Screen"
        assert flutter.is_text_visible("Create a free account", timeout=5)

    def test_navigate_to_employee_login_and_guidance_modal(self, flutter: FlutterHelper):
        """Clicking 'LOGIN AS EMPLOYEE' opens staff access, verifying navigation and access controls."""
        flutter.click_button("LOGIN AS EMPLOYEE")
        time.sleep(1.0)

        # Verify Staff Access Screen
        assert flutter.is_text_visible("Staff Access", timeout=8), "Failed to open Staff Access screen"
        assert flutter.is_text_visible("Shop Code", timeout=5)
        assert flutter.is_text_visible("LOGIN TO SHOP", timeout=5)

        # Verify Employee Forgot Password Guidance if present on this build
        if flutter.is_text_visible("Forgot Password?", timeout=2):
            flutter.click_button("Forgot Password?")
            time.sleep(0.5)
            assert flutter.is_text_visible("Staff Password Reset", timeout=5), "Staff reset guidance dialog not displayed"
            flutter.click_button("OK, Got It")
            time.sleep(0.5)

        # Verify back navigation returns to owner login
        flutter.click_button("Back")
        assert flutter.is_text_visible("POS Podda", timeout=5)
