# CODEBUDDY.md

## Project Overview

This is a multi-platform global file transfer application called "全球法布施" (Global Dharma Sharing) built with Flutter. The project consists of multiple components:

- **Flutter App** (`全球法布施/`): Main cross-platform application (Android, iOS, Web, macOS, Windows, Linux)
- **Cloudflare Worker Backend** (`native-web/deploy-package/`): Authentication, membership, and API services
- **Mobile Capacitor App** (`mobile/`): Hybrid mobile wrapper
- **Backend Proxy** (`backend-proxy/`): Local proxy server for UDP broadcasting

## Development Commands

### Flutter App (Main Directory: `全球法布施/`)

```bash
# Development
flutter pub get                    # Install dependencies
flutter run                       # Run on default device
flutter run -d chrome            # Run on web
flutter run -d android           # Run on Android
flutter run -d ios              # Run on iOS
flutter run -d macos            # Run on macOS

# Quick start scripts
./quick_run.sh                   # Quick run on macOS
./run_web.sh                     # Run web version with full setup
./run_app.sh                     # General app runner

# Building
flutter build web --release      # Build for web
flutter build apk --release      # Build Android APK
flutter build appbundle --release # Build Android App Bundle
flutter build ios --release      # Build for iOS
flutter build macos --release    # Build for macOS
flutter build windows --release  # Build for Windows

# Web-specific builds
./build_web.sh                   # Standard web build
./cloudflare_build.sh           # Optimized for Cloudflare deployment
./build_mobile_optimized.sh     # Mobile-optimized build

# Testing and maintenance
flutter clean                    # Clean build files
flutter doctor                   # Check Flutter setup
flutter analyze                  # Static analysis
flutter test                     # Run tests
```

### Backend Proxy Server

```bash
cd backend-proxy/
npm install                      # Install dependencies
npm start                       # Start proxy server (port varies)
```

### Mobile Capacitor App

```bash
cd mobile/
npm install                      # Install dependencies
# Capacitor commands for hybrid mobile development
```

## Architecture Overview

### Multi-Component Structure
The project uses a distributed architecture with several interconnected components:

1. **Flutter Frontend**: Cross-platform UI and business logic
2. **Cloudflare Workers**: Serverless backend for authentication, payments, and API
3. **Local Proxy**: Bridges web requests to UDP for global broadcasting
4. **Multiple Deployment Targets**: Web, mobile, and desktop platforms

### Key Configuration System
The app uses a sophisticated configuration system (`lib/config/unified_config.dart`) that:
- Automatically detects environment (production/development) based on URL
- Handles CORS issues by using relative paths on web
- Provides fallback backend URLs for reliability
- Supports both Cloudflare Workers and primary backend (ombhrum.com)

### State Management
Uses Provider pattern with multiple models:
- `AuthModel`: User authentication and session management
- `FileTransferModel`: File transfer operations and progress
- `SettingsModel`: Application settings and preferences
- `CountrySendingModel`: Global sending functionality

### Backend Integration
- **Primary Backend**: `https://ombhrum.com`
- **Cloudflare Workers**: 
  - Production: `https://fabushi-flutter-web-prod.bhrumom.workers.dev`
  - Development: `https://fabushi-flutter-web-dev.bhrumom.workers.dev`
- **Features**: JWT authentication, Stripe payments, email verification, membership system

## Key Services and Models

### Core Services (`lib/services/`)
- `app_initializer.dart`: Application startup and configuration
- `unified_api_service.dart`: Centralized API communication
- `auth_service.dart`: Authentication operations
- `membership_service.dart`: Subscription and payment handling
- `global_transfer_service.dart`: File transfer functionality

### Data Models (`lib/models/`)
- Authentication and user management
- File transfer progress and status
- Application settings and preferences
- Country-specific sending configurations

### Platform-Specific Considerations
- **Web**: Uses relative paths to avoid CORS, optimized for Cloudflare Pages
- **Mobile**: Direct API calls to Cloudflare Workers
- **Desktop**: Similar to mobile with platform-specific optimizations

## Deployment

### Web Deployment
```bash
# Build and deploy to Cloudflare Pages
./deploy.sh                      # Full deployment script
./deploy_web.sh                  # Web-specific deployment
./deploy_flutter_web.sh          # Flutter web deployment

# Manual deployment
flutter build web --release --web-renderer html
# Upload build/web/ to Cloudflare Pages
```

### Backend Deployment
The Cloudflare Worker in `native-web/deploy-package/` handles:
- User authentication with JWT tokens
- Stripe payment integration
- Email verification system
- Membership management
- Admin functionality

## Development Notes

### Environment Detection
The app automatically detects environment based on:
- URL patterns for web deployment
- Build-time environment variables
- Fallback to production as default

### API Strategy
- Web platform uses same-origin requests when possible
- Mobile/desktop platforms use direct Cloudflare Worker URLs
- Automatic fallback between multiple backend endpoints
- Comprehensive error handling and retry logic

### Testing and Debugging
- Enable API logging via `UnifiedConfig.enableApiLogging`
- Use `flutter run --verbose` for detailed output
- Check network connectivity with built-in health checks
- Debug authentication flow with detailed console logging