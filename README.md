# Windows 10 search shows files but not apps — the fix that actually worked

You press **Win**, type an app name, and Windows Search shows the wrong things:

- Typing **claude** shows `claude.exe` (a file) instead of the Claude app
- Typing **camera** shows some random folder (even one in the Recycle Bin) instead of the Camera app
- Apps you installed recently never show up, but your files do
- The apps are clearly installed — they're in the Start menu list

If that's you, the usual advice (rebuild the search index, run the troubleshooter, re-register the search app) probably **won't** fix it. Here's what's actually going on and the fix that worked.

## TL;DR

Download [`Fix-SearchApps.ps1`](Fix-SearchApps.ps1) and run it in a normal (non-admin) PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-SearchApps.ps1
```

Then press **Win**, type an app name, and wait 10–15 seconds the first time. That's it.

It only moves the Search app's own data into a backup folder (nothing is deleted), so you can undo it with [`Restore-SearchApps.ps1`](Restore-SearchApps.ps1).

## What's actually wrong

Windows 10 search is split into two parts that are easy to confuse:

| Part | What it does | Where it lives |
|---|---|---|
| **Windows Search indexer** (`SearchIndexer.exe`, the `WSearch` service) | Indexes your **files** | `C:\ProgramData\Microsoft\Search` |
| **Search app** (`SearchApp.exe`, the search panel) | Keeps its own list of **apps** and shows results | `%LOCALAPPDATA%\Packages\Microsoft.Windows.Search_cw5n1h2txyewy` |

When only apps are missing, the indexer is usually fine — that's why rebuilding the index doesn't help. The problem is the **Search app's own app list**, which can get stuck and stop updating. Its state lives in a small settings file (`Settings\settings.dat`) plus cache folders. While that state is stale, search keeps showing an old app list (or none), so it falls back to showing files.

## Check if this is your problem

Run this in PowerShell:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState\ConstraintIndex" -Directory |
  Select-Object Name, LastWriteTime
```

Look at the `Apps_{...}` folders. If their `LastWriteTime` is **months old** even though you've installed apps since, the Search app's app list is stuck — this fix is for you.

## The fix, step by step (if you'd rather not run a script)

1. Open Task Manager and end **Search** (`SearchApp.exe`). It will restart by itself — that's fine.
2. Go to `%LOCALAPPDATA%\Packages\Microsoft.Windows.Search_cw5n1h2txyewy`.
3. Move **everything inside** these folders to a backup folder somewhere else:
   `LocalState`, `Settings`, `AC`, `TempState`, `LocalCache`.
   Don't move or delete the folders themselves, just their contents.
4. If a file says it's in use, end `SearchApp.exe` again and retry. **`Settings\settings.dat` is the important one** — resetting everything except that file did *not* fix it for me.
5. Press **Win**, type an app name, and give it 10–15 seconds to rebuild.

This is what the "Reset" button for an app does. Windows 10 doesn't expose a Reset button for Search, and the `Reset-AppxPackage` cmdlet doesn't exist on many Windows 10 builds, which is why you have to do it by hand.

## What didn't help (so you can skip it)

I tried all of these first. None fixed the missing apps:

- Rebuilding the search index (Indexing Options → Advanced → Rebuild). This slows your PC down for hours and doesn't touch the app list.
- Restarting `SearchApp.exe` or the `WSearch` service
- Re-registering the Search package (`Add-AppxPackage -Register ...AppxManifest.xml`)
- Clearing only `LocalState\DeviceSearchCache`, or only `LocalState`, but leaving `Settings\settings.dat`
- Changing the `InstalledWin32AppsRevision` registry values
- Checking Microsoft's known issue with "Allow website caches and databases". Worth a look, but it wasn't the cause here.

## Undo

The script prints the backup folder it used (`%LOCALAPPDATA%\SearchAppsFix-Backup-<timestamp>`). To put everything back:

```powershell
powershell -ExecutionPolicy Bypass -File .\Restore-SearchApps.ps1 -BackupPath "<that folder>"
```

Once search works again, you can delete the backup folder.

## Notes

- Tested on **Windows 10 22H2 (build 19045)**, on one machine. It should apply to Windows 10 2004 and later, since those versions use `SearchApp.exe`. The script refuses to run on Windows 11, where the search app is packaged differently.
- No admin rights needed. The script only touches your own user's Search app data.
- Your search history and search-panel preferences get reset as a side effect.
- If it's still broken after this, the Search app's own system files may be damaged. Run `DISM /Online /Cleanup-Image /RestoreHealth` and then `sfc /scannow` from an admin prompt.

Found this useful, or it didn't work for you? Open an issue and include your Windows build (`winver`).

## License

MIT
