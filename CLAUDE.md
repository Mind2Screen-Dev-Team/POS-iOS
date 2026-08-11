# CLAUDE.md — POS iOS

POS Penglaris untuk iOS. Swift 5.9, Swift Package Manager (SwiftPM), tanpa `.xcodeproj`.

## Struktur

```
Package.swift                    # platform macOS 13 / iOS 16
Sources/POSiOS/
  App.swift                      # entrypoint @main
  EnvironmentConfig.swift        # base URL via env POS_API_BASE_URL (default https://api.pos.example.com/v1)
  APIClient.swift                # wrapper URLSession + ApiException
  DTOs.swift                     # contoh DTO Product/CartItem/Order
Tests/POSiOSTests/               # unit test (XCTest)
```

## Perintah

```sh
swift build        # kompilasi
swift run          # jalankan entrypoint
swift test         # unit test
```

Butuh Xcode aktif: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`.

## Integrasi backend

- Base URL backend di-inject via env `POS_API_BASE_URL` (default `https://api.pos.example.com/v1`).
- `APIClient` memakai `URLSession` (async/await), `data(for:)` butuh platform iOS 16 / macOS 13.

## Konvensi branch

- Mulai dari `develop`, target merge `develop`. `main` = merge manusia saja. `git pull` dulu sebelum mulai kerja.
