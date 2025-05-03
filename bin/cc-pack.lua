--#region Util
local Util = {}

Util.expect = require("cc.expect").expect
Util.field = require("cc.expect").field
Util.range = require("cc.expect").range
Util.fetch = function(url)
	local response, httpError = http.get(url)

	if response then
		local data = response.readAll()
		response.close()
		return data
	else
		return false, httpError
	end
end
Util.fetchFile = function (url, path)
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

--#region Package
local Package = {}

function Package:new(package_table)
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
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Package:install()
	local function cleanup()
		if fs.exists("/.tmp/" .. self.name) then
			fs.delete("/.tmp/" .. self.name)
		end
	end

	-- TODO: check if package is already installed
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
	if not fs.exists("/.tmp/" .. self.name) then
		fs.makeDir("/.tmp/" .. self.name)
	end

	-- download all files
	Logger.info("Downloading files...")
	Logger.debug("Base path: " .. self.base_path)
	for k, v in pairs(self.file_map) do
		Logger.debug(k .. " > " .. v)
		local url = self.base_path .. k
		local path = "/.tmp/" .. self.name .. "/" .. v

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
		local source = "/.tmp/" .. self.name .. "/" .. v
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
end

local function load_package(package_table) 
	local status, errOrPackage = pcall(function()
		return Package:new(package_table)
	end)

	if not status then
		Logger.error("Invalid package format: ")
		Logger.error(errOrPackage)
		error()
	end

	return errOrPackage
end


--#endregion

local function setup()
	settings.define("cc-pack.log_level", {
		type = "number",
		default = 1,
		description = "The log level for cc-pack. 0 = DEBUG, 1 = INFO, 2 = WARN, 3 = ERROR",
	})
	
	if not fs.exists("/.tmp") then
		fs.makeDir("/.tmp")
	end

	if not fs.exists("/var") then
		fs.makeDir("/var")
	end

	if not fs.exists("/var/cc-pack") then
		fs.makeDir("/var/cc-pack")
	end

	if not fs.exists("/var/cc-pack/packages") then
		fs.makeDir("/var/cc-pack/packages")
	end

	if not fs.exists("/var/cc-pack/remotes") then
		fs.makeDir("/var/cc-pack/remotes")
	end
end

setup()

-- -- TODO: pass in by user
local package_name = "example_package"

local package = load_package({
	name = "example_package",
	version = "1.0.0",
	description = "An example package for testing.",
	author = "Garfeud",
	base_path = "https://raw.githubusercontent.com/Space-Boy-Industries/unicornpkg-repo/refs/heads/main",
	-- key is remote path, value is local path
	file_map = {
		["/sbi_software/startup.lua"] = "/startup/99_sbs_startup.lua",
	},
})

package:install()
Logger.info("Installed package: " .. package.name)
