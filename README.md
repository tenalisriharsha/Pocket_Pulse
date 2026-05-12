# PocketPulse

PocketPulse is an offline first personal finance app built with Flutter. It helps you track transactions, set monthly budgets, manage recurring bills, and view reports, all backed by a local SQLite database.

## Features

### Transactions
- Create accounts (cash, checking, credit)
- Add and edit transactions with amount, date, merchant, notes
- Split transactions across multiple categories
- Filter transactions by account, category, and date

### Budgets
- Set monthly budgets per category
- Monthly summary: budgeted, spent, remaining
- Alerts at 80% and 100% usage
- Optional budget rollover logic

### Recurring
- Create recurring rules (amount, frequency, next due date, account, optional category)
- Upcoming list (14 or 30 day view)
- Mark as paid advances the next due date and creates a transaction
- Local notifications for due reminders
- User configurable reminder time in Settings

### Reports
- Month summary: income, spend, net
- Trend chart (last 6 months)
- Donut chart by category with tap to filter
- Top merchants
- Expense and income toggle

## Tech Stack

- Flutter (Dart)
- State management: Riverpod
- Routing: GoRouter
- Local database: Drift (SQLite)
- Local notifications: flutter_local_notifications
- Time zone handling: timezone, flutter_timezone
- Preferences storage: shared_preferences

## Project Structure (high level)

- `lib/data/local_db/` Drift database, tables, DAOs, seed logic
- `lib/features/` Feature modules (dashboard, transactions, budgets, recurring, reports, settings)
- `lib/shared/` Shared providers and services (database provider, notification service, settings providers)

## Setup

### Prerequisites
- Flutter SDK installed
- macOS: Xcode installed (for macOS build)

### Install dependencies
```bash
flutter pub get

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
