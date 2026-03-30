Project Overview: Bozorim (Margilon Bozor)
Bozorim is a high-performance, cross-platform mobile marketplace designed to digitize local commerce. It bridges the gap between traditional vendors and modern consumers by providing a seamless, real-time platform for buying, selling, and store management.

🛠️ Core Mission
To empower local entrepreneurs with professional-grade digital tools (inventory management, global authentication, and cloud-based scaling) while maintaining an intuitive experience for everyday users.

🏗️ How We Built It (The Tech Stack)
We chose a modern, scalable stack to ensure the app remains fast even as the user base grows:

Frontend: Flutter & Dart – Chosen for a unified codebase across Android and iOS with a high-fidelity custom UI (using Slivers for smooth scrolling).

Backend & Database: Firebase (Cloud Firestore) – Implemented for real-time data syncing, allowing users to see new products instantly without refreshing.

Authentication: Google Sign-In & Firebase Auth – Secured the platform using industry-standard OAuth 2.0.

Media Hosting: Cloudinary – Offloaded image processing and storage to ensure fast loading times for product photos.

State & Logic: Clean architecture separating Services (Auth, Firestore) from the UI, making the code maintainable and bug-resistant.

💡 Challenges We Solved


1. Account Recovery & Data Integrity
The Problem: Users often lose access to accounts or sign in on new devices. We needed to ensure a "Store Owner" didn't lose their shop if they switched phones.

The Solution: I designed a logic-gate in the AuthService that checks the user's email against a stores collection during the login flow. If a match is found, the system automatically "repairs" the link between the new UID and the existing store.

2. Multi-Language Accessibility
The Problem: Traditional localization (i18n) can be heavy and complex for a fast-moving startup project.

The Solution: We implemented a "Global Variable & Route-Reset" strategy. This allowed for instant language switching (Uzbek/English) across the entire app without the overhead of complex provider states, ensuring a low memory footprint.

3. Real-Time Performance vs. Battery Life
The Problem: Constant database polling drains the phone battery.

The Solution: We utilized Streams and Snapshots. The app only "listens" for changes when the user is looking at the screen, ensuring the data is always fresh while being extremely efficient with system resources.

4. Headless Environment Management
The Problem: Coordinating a team of five (Nik, Arif, Emma, Aleeya, and Aishah) while managing hardware configurations.

The Solution: I led the transition to a Git-centric workflow, managing version control via GitHub and configuring development environments in "headless" mode to ensure consistency across the team's machines



# margilon_bozor

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
