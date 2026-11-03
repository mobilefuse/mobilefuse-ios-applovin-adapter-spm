# MobileFuse AppLovin Adapter Swift Package

This repository publishes the Swift Package Manager distribution of the MobileFuse adapter for AppLovin MAX mediation.

## Package URL

`https://github.com/mobilefuse/mobilefuse-ios-applovin-adapter-spm.git`

## Current Release

`1.13.100` (adapter version `1.13.1.0`)

## Package Details

The Swift package builds the MobileFuse AppLovin MAX adapter from source. It depends on:

- MobileFuse iOS SDK `1.13.1` via `https://github.com/mobilefuse/mobilefuse-ios-sdk-spm.git`
- AppLovin SDK `13.x` via `https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git`

## Versioning

Adapter versions have four components (`SDK_MAJOR.SDK_MINOR.SDK_PATCH.ADAPTER_REVISION`), but Swift Package Manager requires three-component tags. Tags use `SDK_MAJOR.SDK_MINOR.(SDK_PATCH * 100 + ADAPTER_REVISION)`:

| Adapter version | Tag |
| --- | --- |
| `1.13.0.0` | `1.13.0` |
| `1.13.0.1` | `1.13.1` |
| `1.13.1.0` | `1.13.100` |
