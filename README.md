# cc-pack
Very simple package manager for computer craft.

## Features
- Install packages from remote repositories, URLs, or local files.
- Uninstall packages.
- Manage remote repositories.

## Advantages
- Descriptive error messages.
- Simple package format.
- Easy to create and host packages.

## Installation 
```
wget run https://raw.githubusercontent.com/foopis23/cc-pack/refs/heads/main/install.lua
```

## Usage

### add (or install) package

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


### rm (or uninstall) package

Remove an installed package.

```
ccp rm <package_name>
```

### remote

Manage remote package repositories.

```
ccp remote <command>
```

Available remote commands:

#### add

Add a remote package repository.

```
ccp remote add <url>
```

#### rm

Remove a remote package repository.

```
ccp remote rm <url>
```

#### list

List all configured remote repositories.

```
ccp remote list
```

## Creating a Package
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
        ["/remote/path/file1.lua"] = "/local/path/file1.lua",
        ["/remote/path/file2.lua"] = "/local/path/file2.lua"
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

## Creating a Remote Repository
A remote repository is just a web server that hosts packages at a specific URL. The package manager will look for packages in the following format:

```
https://<repository_url>/<package_name>.lua
```

### Github as a Remote Repository
You can use GitHub to host your packages. Just create a new repository and add your package files. The package manager will be able to access them using the raw URL.

Base url format:
```
https://raw.githubusercontent.com/<account_or_org>/<repo_name>/refs/heads/<branch_name>
```

## Configuration

The package manager uses ComputerCraft's settings API for configuration. Available settings:

### Logging

Configure the logging level using the `cc-pack.log_level` setting:

```
set cc-pack.log_level <level>
```

Log levels:
- 0 = DEBUG (verbose output)
- 1 = INFO (default, normal output)
- 2 = WARN (warnings only)
- 3 = ERROR (errors only)
