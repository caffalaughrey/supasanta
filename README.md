# supasanta

## Web build and tests

Run tests:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$(pwd)" --unit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$(pwd)" --smoke
```

Export Web:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$(pwd)" --export-release "Web" build/web/index.html
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$(pwd)" --export-release "Web (Threads)" build/web_threads/index.html
```

Size budget check:

```bash
bash tools/ci/check_size.sh build/web 30
bash tools/ci/check_size.sh build/web_threads 30
```
