# MobileFuse AppLovin Adapter Swift Package

This repository publishes the Swift Package Manager distribution of the MobileFuse adapter for AppLovin MAX mediation.

## Package URL

`https://github.com/mobilefuse/mobilefuse-ios-applovin-adapter-spm.git`

## Current Release

`1.13.1` (adapter version `1.13.1.0`)

## Package Details

The Swift package builds the MobileFuse AppLovin MAX adapter from source. It depends on:

- MobileFuse iOS SDK `1.13.1` via `https://github.com/mobilefuse/mobilefuse-ios-sdk-spm.git`
- AppLovin SDK `13.x` via `https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git`

## Versioning

Tags match the MobileFuse iOS SDK version the adapter is built for, so adapter `1.13.1.0` is tagged `1.13.1`. Adapter versions keep four components (`SDK_MAJOR.SDK_MINOR.SDK_PATCH.ADAPTER_REVISION`), but Swift Package Manager tags have three, so a fix to the adapter alone ships with the next SDK patch release.
