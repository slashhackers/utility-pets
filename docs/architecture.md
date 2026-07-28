# Utility Pet architecture

`Utility Pets` is the native macOS host application. The app lives under
`App/UtilityPets`, reusable modules under `Packages`, and each focused utility
under `Pets`.

```
App/UtilityPets/          # App lifecycle and scenes
Packages/PetCore/         # Pet contracts, registry and event bus
Packages/SharedUI/        # Reusable SwiftUI components
Packages/DeviceDiscovery/ # Shared media-device domain types
Pets/Scooby/              # 🐶 Local-media casting pet
```

## Adding a pet

Implement `PetPlugin`, provide a unique identifier and metadata, then register
the pet in `UtilityPetsApp`. The host owns navigation and menu-bar integration;
each pet owns its UI and domain behavior.

## Architecture contract

The native Swift host owns application lifecycle, navigation, menu-bar integration, and service registration (`App/UtilityPets`). Reusable domain modules live under `Packages/`, and each pet implementation (`Pets/Scooby`) remains isolated, providing its own views, view models, and domain behavior.

