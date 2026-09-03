# Campus Lost & Found

A Flutter and Firebase mobile application designed to help students report, discover, and manage lost and found items across a campus.

The application provides a simple workflow for posting lost or found items, searching and filtering existing posts, and managing items created by the authenticated user.

---

## Overview

Campus Lost & Found addresses a common campus problem: students losing personal belongings or finding items that belong to someone else.

Users can:

- Create an account and sign in securely
- Report lost or found items
- Browse available lost and found posts
- Search and filter items
- View detailed item information
- Manage their own posts
- Edit, delete, resolve, and reopen their posts

The application uses Firebase Authentication for user authentication and Cloud Firestore for persistent item data.

---

## Features

### Authentication

- User registration
- Email/password login
- Forgot password
- Logout
- Authentication state handling
- Protected application flow

### Lost & Found Items

- Report lost items
- Report found items
- Select item categories
- Add item title and description
- Add location and date
- Store item ownership information
- Track active and resolved status

### Discovery

- Browse available items
- Search by:
  - Title
  - Description
  - Category
  - Location
- Filter by:
  - Lost / Found
  - Active / Resolved
  - Category
- Combine multiple filters
- Clear filters
- Pull-to-refresh item data

### Item Management

Authenticated users can manage their own posts:

- View their posts
- Edit posts
- Delete posts
- Mark posts as resolved
- Reopen resolved posts

Owner-only actions are enforced through Firestore Security Rules.

### User Experience

- Splash screen with authentication state handling
- Loading states
- Error states
- Empty states
- Retry functionality
- Pull-to-refresh
- Form validation
- Duplicate-submit protection
- Confirmation dialogs for destructive actions
- Reusable UI components

---

## Application Flow

```text
Splash
  |
  +-- Not Authenticated
  |     |
  |     +-- Login
  |     +-- Sign Up
  |     +-- Forgot Password
  |
  +-- Authenticated
        |
        +-- Home
        |     |
        |     +-- Browse Items
        |     +-- Search
        |     +-- Filters
        |     +-- Item Details
        |           |
        |           +-- Edit (Owner)
        |           +-- Delete (Owner)
        |           +-- Resolve / Reopen (Owner)
        |
        +-- Report Item
        |
        +-- My Posts
        |
        +-- Profile

Tech Stack
Technology	Purpose
Flutter	Cross-platform application framework
Dart	Programming language
Firebase Core	Firebase initialization
Firebase Authentication	User authentication
Cloud Firestore	Lost and found item database
Material Design	Application UI
Git	Version control
GitHub	Source code hosting
Current Firebase Services

This project currently uses:

Firebase Authentication
Cloud Firestore

Firebase Storage is not currently used.

Architecture

The project follows a feature-oriented Flutter structure with separation between core functionality, data services, and presentation screens.

lib/
|
+-- core/
|   +-- constants/
|   +-- routes/
|   +-- theme/
|   +-- widgets/
|
+-- data/
|   +-- models/
|   +-- services/
|
+-- presentation/
|   +-- auth/
|   +-- home/
|   +-- item/
|   +-- my_posts/
|   +-- profile/
|   +-- report/
|
+-- firebase_options.dart
+-- main.dart
Core

Contains reusable application infrastructure:

Constants
Routes
Theme configuration
Reusable widgets
Data

Contains:

Firestore data models
Firebase Authentication service
Firestore service
Presentation

Contains the application's user-facing screens organized by feature.

Firestore Data Model

Lost and found posts are stored in the:

lost_found_items

Firestore collection.

Item Document
Field	Type	Description
title	String	Name of the item
description	String	Description of the item
category	String	Item category
type	String	lost or found
location	String	Location associated with the item
date	String	Date associated with the item
ownerId	String	Firebase Authentication UID of the post owner
status	String	active or resolved
imageUrl	String?	Optional image URL field

The ownerId field associates each post with the authenticated user who created it.

Security

Firestore Security Rules are used to protect item data and enforce ownership.

The current rules ensure that:

Only authenticated users can read lost and found items.
Users can create items only when ownerId matches their authenticated UID.
Only the owner can update an item.
The owner cannot transfer ownership by changing ownerId.
Only the owner can delete an item.

This provides server-side ownership enforcement rather than relying only on UI restrictions.

Validation

The application includes validation for item creation and editing.

Item Title
Required
Minimum length: 3 characters
Maximum length: 100 characters
Description
Required
Minimum length: 10 characters
Maximum length: 500 characters
Location
Required
Minimum length: 2 characters
Maximum length: 100 characters
Other Validation
Category selection
Lost/found type selection
Date validation
Password confirmation during registration
Password length validation
Email validation
Duplicate submission protection
Getting Started
Prerequisites

Install the following before running the project:

Flutter SDK
Dart SDK compatible with the project
Android Studio
Android SDK
Android emulator or physical Android device
A Firebase project

The project currently targets a Dart SDK compatible with:

^3.13.2
Clone the Repository
git clone https://github.com/maniprabhas639-ai/campus-lost-found.git
cd campus-lost-found
Install Dependencies
flutter pub get
Configure Firebase

The application requires Firebase configuration.

For Android, the project uses:

android/app/google-services.json

The Flutter Firebase configuration is generated in:

lib/firebase_options.dart

Before running the application, make sure:

Firebase Authentication is configured.
Email/Password authentication is enabled.
Cloud Firestore is enabled.
The Android application is registered with the Firebase project.
The Firebase configuration files correspond to the application.

Do not add Firebase service-account private keys, private credentials, or other sensitive secrets to the repository.

Run the Application

Connect an Android emulator or physical device and run:

flutter run
Development Commands
Analyze the project
flutter analyze
Install dependencies
flutter pub get
Run tests
flutter test
Build a debug APK
flutter build apk --debug
Current Limitations

The current version intentionally keeps the scope focused on the core lost-and-found workflow.

Image upload is not currently implemented.
Firebase Storage is not currently used.
Google Sign-In is not implemented.
In-app messaging between users is not implemented.
Contact-owner communication is not currently implemented as a dedicated messaging system.
Production release signing and deployment configuration have not yet been finalized.
Future Improvements

Possible future enhancements include:

Image upload and preview
Firebase Storage integration
In-app messaging between users
Push notifications
Contact-owner functionality
Improved user profiles
More advanced search
Additional filtering options
Favorite or bookmarked items
Report inappropriate posts
Production branding
Release build configuration
Google Play deployment
Screens

The application currently includes:

Splash
Login
Sign Up
Forgot Password
Home
Report Item
Item Details
My Posts
Edit Item
Profile

Screenshots will be added here as part of the final project presentation.

Project Status

The core application workflow is implemented and tested.

Completed
Authentication
Firebase integration
Firestore item storage
Item creation
Item browsing
Item search
Item filtering
Item details
My Posts
Item editing
Item deletion
Resolve / Reopen functionality
Firestore Security Rules
Form validation
Loading and error handling
Empty states
UI polish
In Progress
Final portfolio presentation
Screenshots
Figma presentation
Demo video
Final documentation
Version

Current application version:

1.0.0+1
License

This project is currently intended for educational and portfolio purposes.

Author

Mani Prabhas

GitHub: https://github.com/maniprabhas639-ai/campus-lost-found
