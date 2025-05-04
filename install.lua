function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
 end


print("Most packages depend on unix-like paths, would you like to install unix-like paths? (Y/n)")
term.setTextColor(colors.lightGray)
print("This will create a startup file to add /bin to path and start you in your /home directory.")
term.setTextColor(colors.white)

local answer = read()
answer = trim(answer)
answer = string.lower(answer)

if answer=="" then
  answer = "y"
end

if answer=="y" or answer=="yes" then
	if not fs.exists("/bin") then
		fs.makeDir("/bin")
	end

	if not fs.exists("/lib") then
		fs.makeDir("/lib")
	end

	if not fs.exists("/home") then
		fs.makeDir("/home")
	end

	if not fs.exists("/etc") then
		fs.makeDir("/etc")
	end

	if not fs.exists("/usr") then
		fs.makeDir("/usr")
	end

	if not fs.exists("/var") then
		fs.makeDir("/var")
	end

	if not fs.exists("/startup") then
		fs.makeDir("/startup")
	end

	if fs.exists("/startup/50_unix_paths.lua") then
		fs.delete("/startup/50_unix_paths.lua")
	end

	local startup_file = fs.open("/startup/50_unix_paths.lua", "w")
	startup_file.write('shell.setPath("/bin:"..shell.path())\nshell.setDir("/home")\n');
	startup_file.close()

	if fs.exist("/bin/ccp.lua") then
		fs.delete("/bin/ccp.lua")
	end

	shell.run("wget https://raw.githubusercontent.com/foopis23/cc-pack/refs/heads/main/bin/ccp.lua /bin/ccp.lua")
else
	if fs.exists("ccp.lua") then
		fs.delete("ccp.lua")
	end

	shell.run("wget https://raw.githubusercontent.com/foopis23/cc-pack/refs/heads/main/bin/ccp.lua ccp.lua")
end
