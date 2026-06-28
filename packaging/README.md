# Packaging notes

This folder documents how to build a distributable extension. It intentionally
contains **no** binaries — RBZ / ZIP / SKP files are not committed to this
repository.

## What ships in an RBZ
A SketchUp `.rbz` file is just a renamed `.zip`. For this extension it must
contain, at the archive root:

```text
su_path_component_array.rb        # loader
su_path_component_array/          # implementation folder
├─ extension.rb
├─ path_sampler.rb
├─ instance_placer.rb
└─ version.rb
```

The README and this `packaging/` folder are not required at runtime and can be
left out of the RBZ.

## Building an RBZ (manual)
From the repository root, zip the loader and the implementation folder, then
rename the archive to `.rbz`.

PowerShell example (run from the repository root):

```powershell
$staging = Join-Path $env:TEMP "su_pca_pkg"
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging | Out-Null

Copy-Item "su_path_component_array.rb" $staging
Copy-Item "su_path_component_array"    $staging -Recurse

Compress-Archive -Path (Join-Path $staging '*') -DestinationPath "su-PathComponentArray-0.1.0.zip" -Force
Rename-Item "su-PathComponentArray-0.1.0.zip" "su-PathComponentArray-0.1.0.rbz"
```

## Installing an RBZ in SketchUp
`Extensions > Extension Manager > Install Extension...` then select the
generated `.rbz`.

> During active development, prefer the symbolic-link workflow described in the
> top-level `README.md` so edits are picked up without rebuilding an RBZ.

## Version bumping
Update the version in **two** places and keep them in sync:

- `su_path_component_array/version.rb` (`VERSION`)
- `README.md` (version reference)
