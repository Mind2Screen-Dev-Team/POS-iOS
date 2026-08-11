# POS iOS — Swift Package

Inisialisasi project POS Penglaris untuk iOS.

**Tech stack:** Swift 5.9, Swift Package Manager (SwiftPM), Foundation (URLSession). Tanpa dependency eksternal. Tanpa `.xcodeproj` — struktur SwiftPM murni.

## Struktur

```
POS-iOS/
├── Package.swift                    # Toolchain 5.9, platform iOS 16 / macOS 13
├── Sources/POSiOS/                 # source target executable
│   ├── main.swift                   # entry point
│   ├── EnvironmentConfig.swift      # base URL backend + timeout (bisa override via env)
│   ├── APIClient.swift              # klien URLSession minimal
│   └── DTOs.swift                   # contoh DTO Product/CartItem/Order
├── Tests/POSiOSTests/              # unit test dasar (XCTest)
└── .gitignore
```

## Build & Run

```sh
swift build        # kompilasi
swift run          # jalankan entry point
swift test         # unit test
```

Override base URL backend saat run:

```sh
POS_API_BASE_URL=https://staging.pos.example.com swift run
```

## Integrasi Backend POS

`APIClient` memakai `URLSession` + JSONDecoder (ISO8601). Base URL default:
`https://api.pos.example.com/v1`. Ganti lewat env `POS_API_BASE_URL` atau edit `EnvironmentConfig.swift`.

Contoh penggunaan (belum dipakai main — tempat fitur tumbuh):

```swift
let client = APIClient()
let products: [ProductDTO] = try await client.request(path: "/products", method: "GET")
```

## Branch Flow

- `main` — stable (merge manual)
- `develop` — integrasi harian
- `staging` — verifikasi staging

## Status

Init only. Fitur bisnis POS (katalog, keranjang, transaksi, sync offline) belum diimplementasikan — ini kerangka minimal yang siap tumbuh.