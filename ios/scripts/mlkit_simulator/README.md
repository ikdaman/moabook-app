# ML Kit Apple Silicon simulator support

Unmodified upstream opt-in helper and license, vendored from flutter-ml/google_ml_kit_flutter
commit `65aa11dab7f2bac81abe6555db48ad3d199bda3f`.

Source: https://github.com/flutter-ml/google_ml_kit_flutter/tree/65aa11dab7f2bac81abe6555db48ad3d199bda3f/packages/google_mlkit_commons/ios/scripts
Documentation: https://github.com/flutter-ml/google_ml_kit_flutter/tree/65aa11dab7f2bac81abe6555db48ad3d199bda3f/packages/google_mlkit_commons#apple-silicon-ios-simulator-ios-26

The installed commons 0.11.1 does not include this helper yet. Podfile opts in
explicitly. It modifies only generated Pods build artifacts. Each build relabels
the arm64 Mach-O platform for the selected simulator/device SDK; it restores the
device label automatically for device builds. This does not add missing camera
hardware to the simulator. Test scanning/OCR on physical devices as well.

To remove: delete the Podfile require and invocation, remove Pods, then reinstall
pods so the original upstream binaries are downloaded again. Do not remove
application data or native source code.
