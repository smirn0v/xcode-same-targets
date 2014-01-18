xcode-same-targets
==================

Check if XCode project targets contains same files. Supports for target exclusive files.

Usage
==================

Just run 'xcode-same-targets' inside project folder to compare all targets together.
In more complex case add ".xcode-same-targets' configuration file inside project folder.

Config file example:
```
{
    "compare-sets": [
        {
            "targets": ["First-AppStore", "Second-AppStore", "Third-AppStore"],
            "exclusive": { 
                          "First-AppStore": [
                                             "/resources/images/first_com/.*$",
                                             "/resources/sounds/message.wav$",
                                            ],
                          "Second-AppStore": [
                                              "/resources/infoplist-strings/second.*$",
                                             ]
                         }
        }
    ],
    "exclusive": {
        "Second-AppStore": [
                            "/resources/settings/mycom-alpha/Settings.bundle$"
                           ]
        "*": ["libPods.*?\.a$"]
    }
}
```

1. Add multiple compare sets.
2. Each compare set contains list of 'targets' to compare.
3. Add exclusive files regex for target globally or specifically for compare set.
4. You may use "*" as a target name inside globall "exclusive" block, it will be applied to all targets.

Here is what 'xcode-same-targets' will do with configuration file above:

**Compare pairs:**
```
[First-AppStore, Second-AppStore]
[First-AppStore, Third-AppStore]
[Second-AppStore, First-AppStore]
[Second-AppStore, Third-AppStore]
[Third-AppStore, First-AppStore]
[Third-AppStore, Second-AppStore]
```
**Example for [First-AppStore, Second-AppStore]**

1. Get list of First-AppStore files
2. Apply "/resources/infoplist-strings/second.\*$", "/resources/settings/mycom-alpha/Settings.bundle$", "libPods.\*?\.a$" regexes to each path from (1) and if it matches add file to list of conflicting.
3. Apply "/resources/images/first_com/.\*$", "/resources/sounds/message.wav$" regexes to conflicting files and if it matches remove file from the list of conflicting.
