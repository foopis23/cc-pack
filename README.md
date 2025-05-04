# cc-pack

A package manager for ComputerCraft that helps you install and manage packages for your ComputerCraft computer.

## Installation

1. Copy the contents of this repository to your ComputerCraft computer
2. The package manager will automatically set up required directories on first run

## Usage

```
ccp <command>
```

### Commands

#### add (or install)

Install a package. Packages can be installed from three different sources:

1. Remote repository:
```
ccp add package_name
```

*When installing by package name, cc-pack will search through configured remote repositories to find the package.*

2. URL:
```
ccp add https://example.com/package.lua
```

3. Local file:
```
ccp add file://path/to/package.lua
```


#### rm (or uninstall)

Remove an installed package.

```
ccp rm <package_name>
```

#### remote

Manage remote package repositories.

```
ccp remote <command>
```

Available remote commands:

##### add

Add a remote package repository.

```
ccp remote add <url>
```

##### rm

Remove a remote package repository.

```
ccp remote rm <url>
```

##### list

List all configured remote repositories.

```
ccp remote list
```

### Package Format

Packages are Lua files that return a table with the following structure:

```lua
{
    name = "package_name",         -- required: string
    version = "1.0.0",            -- optional: string (defaults to "0.0.0")
    description = "Description",   -- optional: string (defaults to "No description provided.")
    author = "Author Name",       -- optional: string (defaults to "Unknown")
    base_path = "https://...",    -- required: string - base URL for file downloads
    file_map = {                  -- required: table mapping remote files to local paths
        ["remote/path/file1.lua"] = "/local/path/file1.lua",
        ["remote/path/file2.lua"] = "/local/path/file2.lua"
    }
}
```

### Example Package

Here's an example package definition that installs from a GitHub repository:

```lua
return {
    name = "example_package",
    version = "1.0.0",
    description = "An example package for testing.",
    author = "Garfeud",
    base_path = "https://raw.githubusercontent.com/Space-Boy-Industries/unicornpkg-repo/refs/heads/main",
    file_map = {
        ["/sbi_software/startup.lua"] = "/startup/99_sbs_startup.lua",
    },
}
```

This example shows how to use a GitHub raw content URL as the base path, which is a common way to distribute ComputerCraft packages.

### Directory Structure

```
/var/cc-pack/
  ├── packages/     -- Installed packages metadata
  ├── remotes/      -- Remote package definitions
  └── .tmp/         -- Temporary files during installation
      └── packages/ -- Temporary package processing
```

### Configuration

The package manager uses ComputerCraft's settings API for configuration. Available settings:

#### Logging

Configure the logging level using the `cc-pack.log_level` setting:

```lua
-- Set via ComputerCraft settings
settings.set("cc-pack.log_level", level)
settings.save()
```

Log levels:
- 0 = DEBUG (verbose output)
- 1 = INFO (default, normal output)
- 2 = WARN (warnings only)
- 3 = ERROR (errors only)

### Installation Process

When installing a package:

1. Package file is validated
2. Files are downloaded to a temporary directory
3. Files are moved to their specified locations
4. Package metadata is stored in `/var/cc-pack/packages/`

When uninstalling a package:

1. All files specified in the package's file_map are removed
2. Empty directories are cleaned up
3. Package metadata is removed from `/var/cc-pack/packages/`