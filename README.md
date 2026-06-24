<img width="187" height="58" alt="image" src="https://github.com/user-attachments/assets/6579befb-e1f3-4835-a52b-39f0ce201d58" />
<img width="319" height="42" alt="image" src="https://github.com/user-attachments/assets/247d42c8-91f4-4d03-9bf8-0c532a561c15" />



# CorgiWalker

Minimal macOS menu bar app in Swift that shows a small animated dog moving left and right inside a status item.

## Build

```sh
./build.sh
```

## Run

```sh
open build/CorgiWalker.app
```

Defaults:

- Width: `72`
- Speed: `1.15`

To start with the papillon instead of the default corgi:

```sh
open build/CorgiWalker.app --args --dog papillon
```

To change how wide the dog can move inside its menu bar slot:

```sh
open build/CorgiWalker.app --args --width 120
```

To change how fast the dog moves:

```sh
open build/CorgiWalker.app --args --speed 1.8
```

You can combine both options:

```sh
open build/CorgiWalker.app --args --dog papillon --width 120 --speed 1.8
```

You can also switch `Dog` from the status item menu after launch, use `Set Width...` or `Set Speed...` there to enter exact numeric values while the app is running, and toggle `Portal` to add orange and blue portal ovals that instantly jump the dog across the middle 30% of the track.

The dog animates inside a fixed-width menu bar item. macOS does not provide a supported way to move an item freely across the entire menu bar, so the animation stays within its own slot.

## Allowing unsigned apps

You may need to "Jailbreak" MacOS to allow unsigned apps.

```sh
sudo spctl --master-disable
```

Then go to Spotlight search -> Privacy & Security -> Allow applications from -> Anywhere
