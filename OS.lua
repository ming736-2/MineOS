
---------------------------------------- System initialization ----------------------------------------

-- Obtaining boot filesystem component proxy
local bootFilesystemProxy = component.proxy(component.invoke(component.list("eeprom")(), "getData"))

-- Executes file from boot HDD during OS initialization (will be overriden in filesystem library later)
function dofile(path)
	local stream, reason = bootFilesystemProxy.open(path, "r")
	
	if stream then
		local data, chunk = ""
		
		while true do
			chunk = bootFilesystemProxy.read(stream, math.huge)
			
			if chunk then
				data = data .. chunk
			else
				break
			end
		end

		bootFilesystemProxy.close(stream)

		local result, reason = load(data, "=" .. path)
		
		if result then
			return result()
		else
			error(reason)
		end
	else
		error(reason)
	end
end

-- Initializing global package system
package = {
	paths = {
		["/Libraries/"] = true
	},
	loaded = {},
	loading = {}
}

-- Checks existense of specified path. It will be overriden after filesystem library initialization
local requireExists = bootFilesystemProxy.exists

-- Works the similar way as native Lua require() function
function require(module)
	-- For non-case-sensitive filesystems
	local lowerModule = unicode.lower(module)

	if package.loaded[lowerModule] then
		return package.loaded[lowerModule]
	elseif package.loading[lowerModule] then
		error("recursive require() call found: library \"" .. module .. "\" is trying to require another library that requires it\n" .. debug.traceback())
	else
		local errors = {}

		local function checkVariant(variant)
			if requireExists(variant) then
				return variant
			else
				table.insert(errors, "  variant \"" .. variant .. "\" not exists")
			end
		end

		local function checkVariants(path, module)
			return
				checkVariant(path .. module .. ".lua") or
				checkVariant(path .. module) or
				checkVariant(module)
		end

		local modulePath
		for path in pairs(package.paths) do
			modulePath =
				checkVariants(path, module) or
				checkVariants(path, unicode.upper(unicode.sub(module, 1, 1)) .. unicode.sub(module, 2, -1))
			
			if modulePath then
				package.loading[lowerModule] = true
				local result = dofile(modulePath)
				package.loaded[lowerModule] = result or true
				package.loading[lowerModule] = nil
				
				return result
			end
		end

		error("unable to locate library \"" .. module .. "\":\n" .. table.concat(errors, "\n"))
	end
end

local GPUAddress = component.list("gpu")()
local screenWidth, screenHeight = component.invoke(GPUAddress, "getResolution")
local hasErrored = false
local oError = error
function error(...)
    local statusText = table.concat({ ... }, " ")
    local screenWidth, screenHeight = component.invoke(GPUAddress, "getResolution")

    local colorsTitle = 0xFFFFFF
    local colorsBackground = 0x0000FF
    local colorsText = 0xFFFFFF
    local colorsSelectionBackground = 0x0000FF
    local colorsSelectionText = 0xFFFFFF

    local function gpuSet(...)
        return component.invoke(GPUAddress, "set", table.unpack({...}))
    end
	local function gpuFill(...)
        return component.invoke(GPUAddress, "fill", table.unpack({...}))
    end

    local function gpuSetBackground(...)
        return component.invoke(GPUAddress, "setBackground", table.unpack({...}))
    end

    local function drawText(x, y, foreground, text)
        component.invoke(GPUAddress, "setForeground", foreground)
        gpuSet(x, y, text)
    end

    local function drawCentrizedText(y, foreground, text)
        drawText(math.floor(screenWidth / 2 - #text / 2), y, foreground, text)
    end
	local function drawRectangle(x, y, width, height, color)
		gpuSetBackground(color)
		gpuFill(x, y, width, height, " ")
	end

    local function drawTitle(y, title)
        y = math.floor(screenHeight / 2 - y / 2)
        drawRectangle(1, 1, screenWidth, screenHeight, colorsBackground)
        drawCentrizedText(y, colorsTitle, title)
        return y + 2
    end

    local lines = {}

    -- Split `statusText` into lines and replace tabs with spaces
    for line in statusText:gmatch("[^\n]+") do
        lines[#lines + 1] = line:gsub("\t", "  ")
    end

    -- Define error mappings
    local errs = {
        ["NO_SUCH_COMPONENT"] = {
            {"no such component", 0x00000001}
        },
        ["OUT_OF_MEMORY"] = {
            {"not enough memory", 0x00000002},
            {"Out of memory", 0x00000002}
        },
        ["INACCESSIBLE_BOOT_DEVICE"] = {
            {"No boot sources found", 0x00000003}
        },
        ["HTTP_CONNECTION_FAILED"] = {
            {"failed to fetch", 0x00000004}
        },
        ["RECOVERY_FAILED"] = {
            {"recovery failed: no internet card", 0x00000005}
        },
        ["LUA_STATE_RETURNED"] = {
            {"computer halted", 0x00000006} -- this shouldn't appear via this function, but is here just in case
        },
		["LUA_NIL_INDEX"] = {
            {"attempt to index a nil value", 0x00000007}
        },
		["LUA_UNFINISHED_DEFINITION"] = {
            {"to close", 0x00000008}
        },
		["DEBUG_RUNLEVEL_NOT_FOUND"] = {
			{"Failed to get debug info for runlevel", 0x00000009}
		},
		["RENDERER_SEGMENT_UNKNOWN"] = {
			{"Че за говно ты сюда напихал? Переделывай!", 0x0000000A}
		},
		["JSON_CIRCULAR_REFERENCE"] = {
			{"circular reference",0x0000000B}
		},
		["DRIVE_MOUNT_FAILED"] = {
			{"bad argument #1 (filesystem proxy expected, got",0x0000000C},
		},
		["DRIVE_UNMOUNT_FAILED"] = {
			{"bad argument #1 (filesystem proxy or mounted path expected, got",0x0000000D}
		},
		["OCGL_UNSUPPORTED_TRIANGLE_RENDER"] = {
			{" doesn't supported for rendering triangles",0x0000000E}
		},
		["CALL_LOADED_MODULE_FAILED"] = {
			{"Failed to call loaded module",0x0000000F}
		},
		["CALL_MODULE_FAILED"] = {
			{"Failed to load module",0x00000010}
		},
		["EXECUTE_MODULE_FAILED"] = {
			{"Failed to execute module",0x00000011}
		}
    }

    -- Check for errors in each line
    local isError = false
    local errorCode = nil

    for i = 1, #lines do
        for key, value in pairs(errs) do
            for _, errorData in ipairs(value) do
                local errorMessage, errorCodeValue = table.unpack(errorData)
                if string.find(lines[i], errorMessage) then
                    isError = true
                    errorCode = {key, errorMessage, errorCodeValue}
                    break
                end
            end
			if isError then
				-- Handle error display with blue background
				if workspace then
					workspace:stop()
				end
				gpuSetBackground(0x0000FF) -- Set background color to blue
				drawRectangle(1, 1, screenWidth, screenHeight, 0x0000FF)
				drawText(1, 1, 0xFFFFFF, "A problem was detected, and MineOS has shut down to prevent damage.")
				drawText(1, 2, 0xFFFFFF, "If this is the first time this has happened, restart your computer.")
				drawText(1, 3, 0xFFFFFF, "If this isn't the first time, then:")
				drawText(1, 5, 0xFFFFFF, "Check your firmware for recent updates. Try downgrading to an older version.")
				drawText(1, 7, 0xFFFFFF, "Try downgrading software you recently updated.")
				drawText(1, 10, 0xFFFFFF, "Technical information:")
				drawText(1, 11, 0xFFFFFF, "Stop code: " .. errorCode[1] .. " (" .. string.format("%02X", errorCode[3]) .. ")")
				drawText(1, 12, 0xFFFFFF, "Traceback:")
				local traceback = debug.traceback()
				local lines = {}
				for line in traceback:gmatch("[^\n]+") do
					lines[#lines + 1] = line:gsub("\t", "  ")
				end
				
				-- Remove the first line (index 1) from the lines table
				table.remove(lines, 1)
				
				-- Display remaining lines
				for y, t in ipairs(lines) do
					drawText(1, 12 + y, 0xFFFFFF, t)
				end
			end
			
        end
    end

    -- If no error is detected, proceed with normal display
    if not isError then
        oError(table.unpack({...}))
    else
		hasErrored = true
		while computer.pullSignal() ~= "keydown" do
			-- Wait until the specified key is pressed
		end
		computer.shutdown(true)
	end
end

_G.error = error


-- Displays title and currently required library when booting OS
local UIRequireTotal, UIRequireCounter = 14, 1

local function UIRequire(module)
	local function centrize(width)
		return math.floor(screenWidth / 2 - width / 2)
	end
	
	local title, width, total = "MineOS", 26, 14
	local x, y, part = centrize(width), math.floor(screenHeight / 2 - 1), math.ceil(width * UIRequireCounter / UIRequireTotal)
	UIRequireCounter = UIRequireCounter + 1
	
	-- Title
	component.invoke(GPUAddress, "setForeground", 0x2D2D2D)
	component.invoke(GPUAddress, "set", centrize(#title), y, title)

	-- Progressbar
	component.invoke(GPUAddress, "setForeground", 0x878787)
	component.invoke(GPUAddress, "set", x, y + 2, string.rep("─", part))

	component.invoke(GPUAddress, "setForeground", 0xC3C3C3)
	component.invoke(GPUAddress, "set", x + part, y + 2, string.rep("─", width - part))

	return require(module)
end

-- Preparing screen for loading libraries
component.invoke(GPUAddress, "setBackground", 0xE1E1E1)
component.invoke(GPUAddress, "fill", 1, 1, screenWidth, screenHeight, " ")

-- Loading libraries
bit32 = bit32 or UIRequire("Bit32")
local paths = UIRequire("Paths")
local event = UIRequire("Event")
local filesystem = UIRequire("Filesystem")

-- Setting main filesystem proxy to what are we booting from
filesystem.setProxy(bootFilesystemProxy)

-- Replacing requireExists function after filesystem library initialization
requireExists = filesystem.exists

-- Loading other libraries
UIRequire("Component")
UIRequire("Keyboard")
UIRequire("Color")
UIRequire("Text")
UIRequire("Number")
local image = UIRequire("Image")
local screen = UIRequire("Screen")

-- Setting currently chosen GPU component as screen buffer main one
screen.setGPUAddress(GPUAddress)

local GUI = UIRequire("GUI")
local system = UIRequire("System")
UIRequire("Network")

-- Filling package.loaded with default global variables for OpenOS bitches
package.loaded.bit32 = bit32
package.loaded.computer = computer
package.loaded.component = component
package.loaded.unicode = unicode

---------------------------------------- Main loop ----------------------------------------

-- Creating OS workspace, which contains every window/menu/etc.
local workspace = GUI.workspace()
system.setWorkspace(workspace)

-- "double_touch" event handler
local doubleTouchInterval, doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = 0.3
event.addHandler(
	function(signalType, componentAddress, x, y, button, user)
		if signalType == "touch" then
			local uptime = computer.uptime()
			
			if doubleTouchX == x and doubleTouchY == y and doubleTouchButton == button and doubleTouchcomponentAddress == componentAddress and uptime - doubleTouchUptime <= doubleTouchInterval then
				computer.pushSignal("double_touch", componentAddress, x, y, button, user)
				event.skip("touch")
			end

			doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = x, y, button, uptime, componentAddress
		end
	end
)

-- Screen component attaching/detaching event handler
event.addHandler(
	function(signalType, componentAddress, componentType)
		if (signalType == "component_added" or signalType == "component_removed") and componentType == "screen" then
			local GPUAddress = screen.getGPUAddress()

			local function bindScreen(address)
				screen.setScreenAddress(address, false)
				screen.setColorDepth(screen.getMaxColorDepth())

				workspace:draw()
			end

			if signalType == "component_added" then
				if not component.invoke(GPUAddress, "getScreen") then
					bindScreen(componentAddress)
				end
			else
				if not component.invoke(GPUAddress, "getScreen") then
					local address = component.list("screen")()
					
					if address then
						bindScreen(address)
					end
				end
			end
		end
	end
)

-- Logging in
system.authorize()

-- Main loop with UI regeneration after errors 
_G.workspace = workspace
_G.system = system
while true do
	local success, path, line, traceback = system.call(workspace.start, workspace, 0)
	
	if success and hasErrored == false then
		break
	else
		--[[system.updateWorkspace()
		system.updateDesktop()
		workspace:draw()
		
		system.error(path, line, traceback)
		workspace:draw()--]]
		error(traceback)
		break
	end
end
