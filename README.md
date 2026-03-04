# POS-PODDA

**POS-PODDA** is a modern, high-performance Point of Sale (POS) and SME business management application built with **Flutter** and powered by **Firebase**. It is designed to provide small and medium enterprises with a robust suite of tools to manage inventory, track sales, administer employee roles, and process transactions securely on the go.

**Live Demo:** [https://pos-podda.web.app](https://pos-podda.web.app)

---

## Key Features

- **Smart POS Scanning & Cart System:** Quick barcode scanning and intuitive cart management for seamless checkout flows.
- **Inventory & Stock Management:** Track products, manage stock batches, set low stock alerts, and handle break-bulk operations. 
- **Role-Based Access Control (RBAC):** Administer employee roles (Admin, Cashier, Manager) with fine-grained permissions and custom profiles.
- **Customer Credit Management:** Track customer histories, manage outstanding balances, and record settlement receipts.
- **Advanced Analytics & Reporting:** Real-time dashboards with visual charts mapping top products, daily sales, and comprehensive CSV export capabilities.
- **Enterprise-Grade Security:** Biometric lock verification (FaceID/Fingerprint) to secure sensitive application areas and enforce strict access policies.
- **Cloud-Synced:** Real-time data synchronization utilizing Firebase backend architecture.
- **Responsive UI/UX:** A beautiful, responsive glassmorphic interface designed for tablets and mobile devices with full dark/light mode support.

---

## Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Firestore, Authentication, Cloud Functions)
- **Architecture:** State Management via Providers, highly modular file structures.

---

## How to Run and Test Locally

To run this project on your local machine, you will need to set up your own Firebase environment, as no production database credentials are included in this public repository for security reasons.

### Prerequisites
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. A free [Firebase Project](https://console.firebase.google.com/).
3. [Firebase CLI](https://firebase.google.com/docs/cli) installed and logged in (`firebase login`).

### Step-by-Step Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/SenanThewnaka/POS-PODDA.git
   cd POS-PODDA
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Since the keys are excluded, you need to link this app to your own Firebase project.
   Run the following command and follow the interactive prompts to generate your `firebase_options.dart` and specific platform keys (`google-services.json` / `GoogleService-Info.plist`).
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

4. **Enable Backend Services:**
   In your newly created Firebase Console, ensure you have enabled:
   - **Firestore Database**
   - **Authentication** (Email/Password)

5. **Run the App:**
   ```bash
   flutter run
   ```

---

## License

This project is licensed under a **Custom Non-Commercial License**. 

You are strictly prohibited from using, selling, reselling, bundling, or distributing this software for commercial purposes or financial gain. For more detailed terms, please see the [LICENSE](LICENSE) file.
