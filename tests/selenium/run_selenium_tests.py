#!/usr/bin/env python3
"""
POS Podda Selenium Test Runner
Executes Login and Signup end-to-end tests against Flutter Web.
"""

import sys
import os
import argparse
import subprocess


def main():
    parser = argparse.ArgumentParser(
        description="Run Selenium end-to-end tests for POS Podda Flutter Web"
    )
    parser.add_argument(
        "--url",
        default="http://localhost:8080",
        help="Target base URL of the Flutter Web application (default: http://localhost:8080)",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run browser in visible mode (default: headless)",
    )
    parser.add_argument(
        "--test",
        choices=["all", "login", "signup"],
        default="all",
        help="Select which test suite to run: all, login, or signup",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Show verbose output from pytest",
    )

    args = parser.parse_args()

    tests_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(os.path.dirname(tests_dir))

    cmd = [
        sys.executable,
        "-m",
        "pytest",
        tests_dir,
        f"--base-url={args.url}",
    ]

    if args.headed:
        cmd.append("--headed")

    if args.test != "all":
        cmd.extend(["-m", args.test])

    if args.verbose:
        cmd.append("-vv")
    else:
        cmd.append("-v")

    print("\n" + "=" * 65)
    print("🚀  POS Podda - Selenium Flutter Web Automated Test Runner")
    print("=" * 65)
    print(f"Target URL : {args.url}")
    print(f"Mode       : {'Headed (Visible Browser)' if args.headed else 'Headless (CI/Background)'}")
    print(f"Suites     : {args.test.upper()}")
    print("=" * 65 + "\n")

    env = os.environ.copy()
    env["PYTHONPATH"] = f"{project_dir}:{env.get('PYTHONPATH', '')}"

    result = subprocess.run(cmd, env=env)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
