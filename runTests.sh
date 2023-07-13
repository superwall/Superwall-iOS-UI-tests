#!/bin/bash

declare -a schemes=("UI Tests -swift -automatic" "UI Tests -swift -advanced" "UI Tests -objc -automatic" "UI Tests -objc -advanced")
destination='platform=iOS Simulator,name=iPhone 14 Pro,OS=16.4'

for scheme in "${schemes[@]}"
do
   echo "Running tests for scheme: $scheme"
   xcodebuild test -scheme "$scheme" -destination "$destination"
done
