--#region Constants
local TMP_DIR = "/var/cc-pack/.tmp"
local TMP_PACKAGE_DIR = TMP_DIR .. "/packages/"
local PACKAGES_DIR = "/var/cc-pack/packages"
local REMOTES_FILE = "/var/cc-pack/remotes.dat"

--#endregion

--#region Util
local Util = {}

Util.expect = require("cc.expect").expect
Util.field = require("cc.expect").field
Util.range = require("cc.expect").range
function Util.fetch(url)
	local response, httpError = http.get(url)

	if response then
		local data = response.readAll()
		response.close()
		return data
	else
		return false, httpError
	end
end

function Util.fetchFile(url, path)
	local data, error = Util.fetch(url)
	if data then
		local file = fs.open(path, "w")
		if file then
			file.write(data)
			file.close()
		else
			return false, "Failed to open file for writing: " .. path
		end
		return true
	else
		return false, error
	end
end

function Util.handleOptionalLuaPaths(path)
	-- if path has .lua, remove it
	if string.sub(path, -4) == ".lua" then
		path = string.sub(path, 1, -5)
	end

	return path .. "?.lua"
end

--#endregion

--#region Logger
local Logger = {}
Logger.levels = {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
}
Logger.getLevel = function()
	local level = settings.get("cc-pack.log_level")
	if type(level) ~= "number" then
		level = 1
	end

	return level
end

Logger.setLevel = function(level)
	Util.expect(1, level, "number")
	Util.range(level, 0, 3)
	settings.set("cc-pack.log_level", level)
	settings.save()
end

Logger.log = function(level, message)
	Util.expect(1, level, "number")
	Util.expect(2, message, "string")

	if level >= Logger.getLevel() then
		
		if level == Logger.levels.ERROR then
			printError(message)
		elseif level == Logger.levels.WARN then
			term.setTextColor(colors.yellow)
			print(message)
		elseif level == Logger.levels.INFO then
			term.setTextColor(colors.white)
			print(message)
		elseif level == Logger.levels.DEBUG then
			term.setTextColor(colors.lightGray)
			print(message)
		end
	end
end

Logger.debug = function(message)
	Util.expect(1, message, "string")
	Logger.log(Logger.levels.DEBUG, message)
end

Logger.info = function(message)
	Util.expect(1, message, "string")
	Logger.log(Logger.levels.INFO, message)
end

Logger.warn = function(message)
	Util.expect(1, message, "string")
	Logger.log(Logger.levels.WARN, message)
end

Logger.error = function(message)
	Util.expect(1, message, "string")
	Logger.log(Logger.levels.ERROR, message)
end
--#endregion

--#region Remote
local function init_remotes()
	if not fs.exists(REMOTES_FILE) then
		local file = fs.open(REMOTES_FILE, "w")
		file.write(textutils.serialize({}))
		file.close()
	end
end

local function load_remotes()
	local remotes = {}
	local file = fs.open(REMOTES_FILE, "r")
	local data = file.readAll()
	file.close()
	remotes = textutils.unserialize(data)
	return remotes
end

local function save_remotes(remotes)
	local file = fs.open(REMOTES_FILE, "w")
	file.write(textutils.serialize(remotes))
	file.close()
end

local function add_remote(base_url)
	Util.expect(1, base_url, "string")
	local status, error = http.checkURL(base_url)
	if not status then
		Logger.error("Invalid URL: " .. base_url)
		error()
	end

	local remotes = load_remotes()
	-- if remotes array contains the base_url, return
	for _, remote in ipairs(remotes) do
		if remote == base_url then
			return false
		end
	end

	-- add the base_url to the remotes array
	table.insert(remotes, base_url)
	save_remotes(remotes)

	return true
end

local function remove_remote(base_url)
	Util.expect(1, url, "string")
	local remotes = load_remotes()
	-- if remotes array contains the base_url, return
	for i, remote in ipairs(remotes) do
		if remote == base_url then
			table.remove(remotes, i)
			save_remotes(remotes)
			return true
		end
	end

	return false
end
--#endregion

--#region Package
local Package = {}

function Package:new(package_table, local_path)
	Util.expect(1, package_table, "table")
    
    if package_table then
        Util.field(package_table, "name", "string")
        Util.field(package_table, "version", "string", "nil")
        Util.field(package_table, "description", "string", "nil")
        Util.field(package_table, "author", "string", "nil")
		Util.field(package_table, "base_path", "string")
        Util.field(package_table, "file_map", "table")

        if package_table.file_map then
			for k, v in pairs(package_table.file_map) do
				Util.expect(1, k, "string")
				Util.expect(2, v, "string")
			end
        end
    end

	local obj = {
		name = package_table.name,
		version = package_table.version or "0.0.0",
		description = package_table.description or "No description provided.",
		author = package_table.author or "Unknown",
		file_map = package_table.file_map,
		base_path = package_table.base_path,
		local_path = local_path
	}

	-- if base_path ends with /, remove it
	if string.sub(obj.base_path, -1) == "/" then
		obj.base_path = string.sub(obj.base_path, 1, -2)
	end

	-- if key in file_map doesn't start with /, add it.
	local new_file_map = {}
	for k, v in pairs(obj.file_map) do
		if string.sub(k, 1, 1) ~= "/" then
			k = "/" .. k
		end
		new_file_map[k] = v
	end

	obj.file_map = new_file_map

	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Package:install()
	-- TODO: check if package is already installed
	local function cleanup()
		if fs.exists(TMP_DIR .. self.name) then
			fs.delete(TMP_DIR .. self.name)
		end
	end

	local failCleanup = function()
		for k, v in pairs(self.file_map) do
			local path = k;
			if fs.exists(path) then
				fs.delete(path)
			end
			if fs.exists(fs.getDir(path)) and fs.isDir(fs.getDir(path)) then
				fs.delete(fs.getDir(path))
			end
		end
	end
	
	-- create a tmp directory
	if not fs.exists(TMP_DIR .. self.name) then
		fs.makeDir(TMP_DIR .. self.name)
	end

	-- download all files
	Logger.info("Downloading files...")
	Logger.debug("Base path: " .. self.base_path)
	for k, v in pairs(self.file_map) do
		Logger.debug(k .. " > " .. v)
		local url = self.base_path .. k
		local path = TMP_DIR .. self.name .. "/" .. v

		if not fs.exists(fs.getDir(path)) or fs.isDir(fs.getDir(path)) then
			fs.makeDir(fs.getDir(path))
		end

		local status, err = Util.fetchFile(url, path)
		if not status then
			Logger.error("Failed to install package. Could not fetch file: " .. url)
			Logger.error(err)
			failCleanup()
			error()
		end
	end

	-- move files to the correct location
	Logger.info("Installing files...")
	for k, v in pairs(self.file_map) do
		local source = TMP_DIR .. self.name .. "/" .. v
		local dest = v;

		Logger.debug(source .. " > " .. dest)

		-- check if the destination is a directory
		if fs.exists(dest) then
			fs.delete(dest)
		end

		-- make sure directory exists
		if not fs.exists(fs.getDir(dest)) or fs.isDir(fs.getDir(dest)) then
			fs.makeDir(fs.getDir(dest))
		end

		if fs.exists(source) then
			fs.move(source, dest)
		else
			Logger.error("Failed to install package. Could not move file: " .. source)
			failCleanup()
			error()
		end
	end

	Logger.info("Cleaning up...")
	cleanup()

	-- move the package to /var/cc-pack/packages
	-- doing so marks it as "installed"
	if self.local_path then
		local name = fs.getName(self.local_path)
		local dest = PACKAGES_DIR .. "/" .. name
		if fs.exists(dest) then
			fs.delete(dest)
		end
		fs.move(self.local_path, dest)
		fs.delete(self.local_path)
	end
end

function Package:uninstall()
	-- delete all the files from the file-map
	for k, v in pairs(self.file_map) do
		local path = v
		if fs.exists(path) then
			fs.delete(path)
		end

		-- if dir is empty, delete it
		local dir = fs.getDir(path)
		if fs.exists(dir) and fs.isDir(dir) then
			local files = fs.list(dir)
			if #files == 0 then
				fs.delete(dir)
			end
		end
	end

	-- delete the package file
	if fs.exists(self.local_path) then
		fs.delete(self.local_path)
	end
end

local function load_package(path)
	path = Util.handleOptionalLuaPaths(path)

	if not fs.exists(path) then
		Logger.error("Package file does not exist: " .. path)
		error()
	end

	local package_table = dofile(path)

	local status, errOrPackage = pcall(function()
		return Package:new(package_table, path)
	end)

	if not status then
		Logger.error("Invalid package format: ")
		Logger.error(errOrPackage)
		error()
	end

	return errOrPackage
end

local function load_local_package(path)
	path = Util.handleOptionalLuaPaths(path)
	if not fs.exists(path) then
		Logger.error("Package file does not exist: " .. path)
		error()
	end

	local file_name = fs.getName(path)
	local tmp_path = TMP_PACKAGE_DIR .. file_name

	if fs.exists(tmp_path) then
		fs.delete(tmp_path)
	end
	fs.copy(path, tmp_path)
	return load_package(tmp_path)
end

local function is_package_installed(name)
	local path = Util.handleOptionalLuaPaths(PACKAGES_DIR .. "/" .. name)
	if fs.exists(path) then
		return true
	end
	return false
end

local function load_package_from_remote(name)
	local remotes = load_remotes()
	-- loop through remotes until we find a version of the package
	for _, remote in ipairs(remotes) do
		local url = remote .. "/" .. name
		local status, error = http.checkURL(url)
		if not status then
			Logger.error("Invalid URL: " .. url)
			error()
		end

		local tmp_path = TMP_DIR .. '/' .. name .. '.lua'
		local downloaded = Util.fetchFile(url .. '.lua', tmp_path)

		-- try to load package without the .lua extension
		if not downloaded then
			downloaded = Util.fetchFile(url, tmp_path)
		end

		if downloaded then
			local package = load_package(tmp_path)
			return package
		end

		-- if package is not found, keep looking
	end

	return false, "Package not found: " .. name
end

local function load_package_from_url(url)
	local status, error = http.checkURL(url)
	if not status then
		Logger.error("Invalid URL: " .. url)
		error()
	end

	local data, err = Util.fetch(url)

	if data then
		local file = fs.open(TMP_DIR .. fs.getName(url), "w")
		if file then
			file.write(data)
			file.close()
		else
			return false, "Failed to open file for writing: " .. TMP_DIR .. fs.getName(url)
		end
		local package = load_package(TMP_DIR .. fs.getName(url))
		return package
	end

	return false, "Package not found: " .. url
end

--#endregion

--#region Usage
local Usage = {
	usage = function()
		Logger.info("Usage: ccp <command>")
		Logger.info("Commands:")
		Logger.info("  add <package> - Install a package")
		Logger.info("  rm <package> - Uninstall a package")
	end,
	install = function()
		Logger.info("Usage: ccp add <package>")
		Logger.info("Install a package from a remote, url, or local file.")
		Logger.info("  <package> - The name, url, or path to the package.")
		Logger.info("    - If a url, it should be in the format http://example.com/package.lua")
		Logger.info("    - If a local file, it should be in the format file://path/to/package.lua")
	end,
	uninstall = function()
		Logger.info("Usage: ccp rm <package>")
		Logger.info("Uninstall a package.")
		Logger.info("  <package> - The name of the package to uninstall.")
	end,
	remote = {
		usage = function()
			Logger.info("Usage: ccp remote <command>")
			Logger.info("Commands:")
			Logger.info("  add <url> - Add a remote repository")
			Logger.info("  rm <url> - Remove a remote repository")
		end,
		add = function()
			Logger.info("Usage: ccp remote add <url>")
			Logger.info("Add a remote repository.")
			Logger.info("  <url> - The URL of the remote repository.")
		end,
		rm = function()
			Logger.info("Usage: ccp remote rm <url>")
			Logger.info("Remove a remote repository.")
			Logger.info("  <url> - The URL of the remote repository.")
		end,
		list = function()
			Logger.info("Usage: ccp remote list")
			Logger.info("List all remote repositories.")
		end,
	}
}
--#endregion

local function setup()
	settings.define("cc-pack.log_level", {
		type = "number",
		default = 1,
		description = "The log level for cc-pack. 0 = DEBUG, 1 = INFO, 2 = WARN, 3 = ERROR",
	})

	if not fs.exists(TMP_DIR) then
		fs.makeDir(TMP_DIR)	
	end

	if not fs.exists(TMP_PACKAGE_DIR) then
		fs.makeDir(TMP_PACKAGE_DIR)
	end

	if not fs.exists(PACKAGES_DIR) then
		fs.makeDir(PACKAGES_DIR)
	end

	init_remotes()
end

setup()


local args = {...}

if #args < 1 then
	Logger.error("Error: Missing command.")
	Usage.usage()
	return
end

local command = args[1]

if command == "install" or command == 'add' then
	if #args < 2 then
		Logger.error("Error: Missing package path.")
		Usage.install()
		return
	end

	-- three types of packages resolvers:
	-- 1. local package file://path/to/package.lua
	-- 2. url package http(s)://example.com/package.lua
	-- 3. package name (resolve from remotes)

	local package_path = args[2]
	local package = nil
	if string.sub(package_path, 1, 7) == "file://" then
		-- local package
		package_path = string.sub(package_path, 7)
		package = load_local_package(package_path)
	elseif string.sub(package_path, 1, 7) == "http://" or string.sub(package_path, 1, 8) == "https://" then
		-- url package
		package = load_package_from_url(package_path)
	else
		-- package name
		package = load_package_from_remote(package_path)
	end

	if not package then
		Logger.error("Error: Failed to load package: " .. package_path)
		return
	end

	-- local package = load_local_package(package_path)
	package:install()
elseif command == "uninstall" or command == 'rm' then
	if #args < 2 then
		Logger.error("Error: Missing package name.")
		Usage.uninstall()
		return
	end

	if not is_package_installed(args[2]) then
		Logger.error("Error: Package not installed: " .. args[2])
		return
	end

	local package_name = args[2]
	local package = load_package(PACKAGES_DIR .. "/" .. package_name)

	package:uninstall()
	Logger.info("Uninstalled package: " .. package_name)

elseif command == "remote" then
	local subcommand = args[2]
	if not subcommand then
		Logger.error("Error: Missing subcommand.")
		Usage.remote.usage()
		return
	end

	if subcommand == "add" then
		if #args < 3 then
			Logger.error("Error: Missing remote URL.")
			Usage.remote.add()
			return
		end

		local url = args[3]
		print(url)
		local status = add_remote(url)
		if status then
			Logger.info("Added remote: " .. url)
		else
			Logger.warn("Remote already exists: " .. url)
		end
	elseif subcommand == "rm" then
		if #args < 3 then
			Logger.error("Error: Missing remote URL.")
			Usage.remote.rm()
			return
		end

		local url = args[3]
		local status = remove_remote(url)
		if status then
			Logger.info("Removed remote: " .. url)
		else
			Logger.info("Remote not found: " .. url)
		end
	elseif subcommand == "list" then
		local remotes = load_remotes()
		if #remotes == 0 then
			Logger.info("No remotes found.")
		else
			Logger.info("Remotes:")
			for _, remote in ipairs(remotes) do
				Logger.info("  " .. remote)
			end
		end
	else
		Logger.error("Error: Unknown subcommand: " .. subcommand)
		Usage.remote.usage()
		return
	end
else
	Logger.error("Error: Unknown command: " .. command)
	Usage.usage()
	return
end
