import os
import time
from typing import Optional, List
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.remote.webelement import WebElement
from selenium.common.exceptions import (
    TimeoutException,
    NoSuchElementException,
    ElementClickInterceptedException,
    StaleElementReferenceException,
)


class FlutterHelper:
    """
    Robust Selenium automation helper tailored specifically for Flutter Web.
    Handles Flutter CanvasKit & HTML renderer semantics, accessibility tree activation,
    and responsive element location.
    """

    def __init__(self, driver: webdriver.Chrome, default_timeout: int = 15):
        self.driver = driver
        self.timeout = default_timeout
        self.wait = WebDriverWait(driver, default_timeout)

    def wait_for_flutter_app(self, timeout: Optional[int] = None) -> bool:
        """Waits for the Flutter web application to mount and render."""
        t = timeout or self.timeout
        start = time.time()
        while time.time() - start < t:
            try:
                # Check for Flutter engine view or scene host
                has_flutter = self.driver.execute_script(
                    "return !!(document.querySelector('flutter-view') || "
                    "document.querySelector('flt-scene-host') || "
                    "document.querySelector('flt-glass-pane') || "
                    "document.querySelector('body > flt-semantics-placeholder'));"
                )
                if has_flutter:
                    time.sleep(1.0)  # Allow initial render frame to stabilize
                    self.enable_accessibility()
                    return True
            except Exception:
                pass
            time.sleep(0.5)
        return False

    def enable_accessibility(self) -> None:
        """
        Activates Flutter's Web Accessibility Tree.
        Flutter Web renders via CanvasKit unless semantics mode is activated.
        Activating semantics generates accessible DOM elements (<flt-semantics>)
        with proper ARIA attributes, inputs, and button roles.
        """
        if getattr(self, "_accessibility_enabled", False):
            return
        try:
            script = """
                const placeholder = document.querySelector('flt-semantics-placeholder');
                if (placeholder) {
                    placeholder.click();
                    placeholder.dispatchEvent(new Event('focus'));
                }
                const btn = document.querySelector('[aria-label="Enable accessibility"]');
                if (btn) {
                    btn.click();
                }
            """
            self.driver.execute_script(script)
            self._accessibility_enabled = True
            time.sleep(0.5)
        except Exception:
            pass

    def find_semantic(
        self,
        label_or_text: str,
        role: Optional[str] = None,
        timeout: Optional[int] = None,
    ) -> WebElement:
        """
        Finds a Flutter semantic element by label or text.
        Searches aria-label, text content, and role attributes.
        """
        self.enable_accessibility()
        t = timeout or self.timeout

        if role:
            xpath = f"//*[@role='{role}' and (contains(@aria-label, '{label_or_text}') or contains(., '{label_or_text}'))]"
        else:
            xpath = f"//*[contains(@aria-label, '{label_or_text}') or contains(., '{label_or_text}')]"

        try:
            return WebDriverWait(self.driver, t).until(
                EC.presence_of_element_located((By.XPATH, xpath))
            )
        except (TimeoutException, NoSuchElementException):
            # Fallback to secondary xpath if needed
            fallback_xpath = f"//flt-semantics[contains(@aria-label, '{label_or_text}') or contains(., '{label_or_text}')]"
            try:
                return WebDriverWait(self.driver, 1).until(
                    EC.presence_of_element_located((By.XPATH, fallback_xpath))
                )
            except Exception:
                raise TimeoutException(
                    f"Could not locate Flutter semantic element with label/text: '{label_or_text}' (role={role})"
                )

    def find_input(self, label_text: str, timeout: Optional[int] = None) -> WebElement:
        """
        Locates the HTML <input> or <textarea> element corresponding to a Flutter text field.
        """
        self.enable_accessibility()
        t = timeout or self.timeout

        xpaths = [
            # Direct input with aria-label
            f"//input[contains(@aria-label, '{label_text}')]",
            f"//textarea[contains(@aria-label, '{label_text}')]",
            # Semantic node containing label with input child
            f"//flt-semantics[contains(@aria-label, '{label_text}')]//input",
            f"//flt-semantics[contains(@aria-label, '{label_text}')]//textarea",
            # Semantic host following label
            f"//flt-semantics[contains(@aria-label, '{label_text}')]/following-sibling::flt-semantics//input",
            # Generic input inside flt-text-editing-host
            "//flt-text-editing-host//input",
        ]

        for xp in xpaths:
            try:
                el = WebDriverWait(self.driver, t / len(xpaths) + 1).until(
                    EC.presence_of_element_located((By.XPATH, xp))
                )
                if el:
                    return el
            except (TimeoutException, NoSuchElementException):
                continue

        # Fallback: find the semantic container and click it to invoke input focus
        sem = self.find_semantic(label_text, timeout=t)
        self.click_element(sem)
        time.sleep(0.5)

        # After clicking the container, check the active/focused input element
        active_el = self.driver.switch_to.active_element
        if active_el and active_el.tag_name in ("input", "textarea"):
            return active_el

        # Final check for any visible text editing host input
        inputs = self.driver.find_elements(By.CSS_SELECTOR, "input:not([type='hidden'])")
        if inputs:
            return inputs[0]

        raise TimeoutException(f"Could not locate input field for label: '{label_text}'")

    def type_into(self, target: str, text: str, clear_first: bool = True) -> None:
        """
        Focuses an input field identified by label or element, clears previous content,
        and sends keys reliably.
        """
        input_el = self.find_input(target)
        try:
            input_el.click()
        except Exception:
            self.driver.execute_script("arguments[0].focus();", input_el)

        time.sleep(0.1)
        if clear_first:
            try:
                input_el.clear()
            except Exception:
                pass
            input_el.send_keys(Keys.COMMAND + "a")
            input_el.send_keys(Keys.CONTROL + "a")
            input_el.send_keys(Keys.BACKSPACE)
            # Sync Flutter virtual text controller by dispatching input/change events
            self.driver.execute_script("""
                arguments[0].value = '';
                arguments[0].dispatchEvent(new Event('input', { bubbles: true }));
                arguments[0].dispatchEvent(new Event('change', { bubbles: true }));
            """, input_el)

        if text:
            input_el.send_keys(text)
            self.driver.execute_script("""
                arguments[0].dispatchEvent(new Event('input', { bubbles: true }));
            """, input_el)
        time.sleep(0.1)

    def click_button(self, button_text: str, timeout: Optional[int] = None) -> None:
        """Finds and clicks a button by its display text or aria-label."""
        self.enable_accessibility()
        btn = self.find_semantic(button_text, role="button", timeout=timeout)
        self.click_element(btn)

    def click_element(self, element: WebElement) -> None:
        """Clicks an element using standard click with fallback to ActionChains and JS click."""
        try:
            element.click()
        except (ElementClickInterceptedException, StaleElementReferenceException):
            try:
                actions = ActionChains(self.driver)
                actions.move_to_element(element).click().perform()
            except Exception:
                self.driver.execute_script("arguments[0].click();", element)

    def is_text_visible(self, text: str, timeout: int = 5) -> bool:
        """Returns True if the text or message appears on screen within timeout."""
        try:
            self.find_semantic(text, timeout=timeout)
            return True
        except TimeoutException:
            # Also check page source / body text as fallback
            return text.lower() in self.driver.page_source.lower()

    def wait_for_snackbar_or_dialog(self, text_snippet: str, timeout: int = 6) -> bool:
        """Waits for a floating SnackBar, modal dialog, or notification containing text_snippet."""
        return self.wait_for_any_message([text_snippet], timeout=timeout)

    def wait_for_any_message(self, snippets: list[str], timeout: int = 6) -> bool:
        """Waits for ANY of the given message snippets to appear in a SnackBar or dialog."""
        start = time.time()
        while time.time() - start < timeout:
            for snippet in snippets:
                xpath = f"//*[contains(@aria-label, '{snippet}') or contains(., '{snippet}')]"
                try:
                    els = self.driver.find_elements(By.XPATH, xpath)
                    for el in els:
                        combined = (el.text or "") + " " + (el.get_attribute("aria-label") or "")
                        if snippet.lower() in combined.lower():
                            return True
                except Exception:
                    pass
            time.sleep(0.15)
        return False

    def take_screenshot(self, name: str) -> str:
        """Saves a debug screenshot to reports/screenshots/."""
        reports_dir = os.path.join(os.path.dirname(__file__), "reports", "screenshots")
        os.makedirs(reports_dir, exist_ok=True)
        filename = f"{name}_{int(time.time())}.png"
        filepath = os.path.join(reports_dir, filename)
        self.driver.save_screenshot(filepath)
        return filepath
