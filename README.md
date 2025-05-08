# SPM and CocoaPod Dependency version check

This step creates a csv file that contains all the dependencies used in an xcode project or swift package.

The step will look for a Package.resolved file and/or a Podfile.

The csv will contain the name of the dependency, the current version used, the latest version available, the git repo (for SPM) and an indicator of the dependency being either SPM or POD

This step uses [pod outdated](https://guides.cocoapods.org/terminal/commands.html#pod_outdated) to get the Cocoapod dependencies and [swift-outdated](https://github.com/kiliankoe/swift-outdated) for swift package dependencies

## How to use this Step

This step requires two inputs:

- ```package_resolved_path```: This needs to contain the path to your Package.resolved file
- ```project_source_path```: This needs to conatin the path to the root or your project or package.

The step will generate a csv file - sbom.csv

the location of the file will be in the output varaiable ```$DEPENDENCY_VERSION_CHECK_RESULT_FILE```