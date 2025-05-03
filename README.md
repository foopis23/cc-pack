# cc-pack

A package manager for ComputerCraft that helps you install and manage packages for your ComputerCraft computer.

## Installation

Coming soon. Still in development.

## Usage

```
cc-pack <command>
```

### Commands

#### install

Install a package from the local filesystem.

```
cc-pack install <package_path>
```

### Package Format

Packages are Lua files that return a table with the following structure:

```lua
{
    name = "package_name",         -- required: string
    version = "1.0.0",            -- optional: string (defaults to "0.0.0")
    description = "Description",   -- optional: string
    author = "Author Name",       -- optional: string
    base_path = "https://...",    -- required: string - base URL for file downloads
    file_map = {                  -- required: table mapping remote files to local paths
        ["/file1.lua"] = "/path/to/local/file1.lua",
        ["/file2.lua"] = "/path/to/local/file2.lua"
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
  ├── packages/     -- Installed packages
  ├── remotes/      -- Remote package definitions
  └── .tmp/         -- Temporary files during installation
```

### Logging

The tool supports different logging levels that can be configured:
- 0 = DEBUG
- 1 = INFO (default)
- 2 = WARN
- 3 = ERROR

You can change the log level in the ComputerCraft settings by running the following command:
```
set cc-pack.log_level <level>
```