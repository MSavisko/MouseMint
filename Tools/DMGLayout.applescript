on run arguments
    set mountPath to item 1 of arguments
    set diskFolder to POSIX file mountPath as alias
    tell application "Finder"
        tell folder diskFolder
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {300, 200, 980, 648}
            set options to icon view options of container window
            set arrangement of options to not arranged
            set icon size of options to 100
            set text size of options to 14
            set background picture of options to file ".background:background.png"
            set position of item "MouseMint.app" to {180, 210}
            set position of item "Applications" to {500, 210}
            close
            open
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
