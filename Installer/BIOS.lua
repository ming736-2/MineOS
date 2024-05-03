
local result, reason = ""
function error(...)
	local statusText = table.concat({ ... }," ")
	local screenWidth, screenHeight = component.invoke(GPUAddress,"getResolution")

	local colorsTitle,
	colorsBackground,
	colorsText,
	colorsSelectionBackground,
	colorsSelectionText = 0x2D2D2D,
	0xE1E1E1,
	0x878787,
	0x878787,
	0xE1E1E1

	local function gpuSet(...)
		return component.invoke(GPUAddress, "set", unpack(...))
	end
	local function gpuSetBackground(...)
		return component.invoke(GPUAddress, "setBackground", unpack(...))
	end
	local function drawText(x, y, foreground, text)
		component.invoke(GPUAddress, "setForeground", foreground)
		gpuSet(x, y, text)
	end
	local function drawCentrizedText(y, foreground, text)
		drawText(math.floor(screenWidth / 2 - #text / 2), y, foreground, text)
	end
	local function drawTitle(y, title)
		y = mathFloor(screenHeight / 2 - y / 2)
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
        ["NO_SUCH_COMPONENT"] = {"no such component", 0x00000001},
        ["OUT_OF_MEMORY"] = {"not enough memory", 0x00000002},
        ["INACCESSIBLE_BOOT_DEVICE"] = {"No boot sources found", 0x00000003},
		["HTTP_CONNECTION_FAILED"] = {"failed to fetch",0x00000004},
		["RECOVERY_FAILED"] = {"recovery failed: no internet card",0x00000005},
		["LUA_STATE_RETURNED"] = {"computer halted",0x00000006}, -- this error should NEVER happen but this is here anyway
		["LUA_INVALID_CHARACTER"] = {"unexpected symbol near",0x00000007}
    }

    -- Check for errors in each line
    local isError = false
    local errorCode = nil

    for i = 1, #lines do
        for key, value in pairs(errs) do
            if string.find(lines[i], value[1]) then
                isError = true
                errorCode = {key,value[1],value[2]}
                break
            end
        end
        if isError then
            -- Handle error display with blue background
            gpuSetBackground(0x0000FF)  -- Set background color to blue
            local y = drawTitle(#lines, "An error has occurred")
            for j = 1, #lines do
                drawCentrizedText(y, 0x000000, errorCode[1].." ("..string.format("%02X", errorCode[3])..")")
                y = y + 1
            end
            return  -- Exit the function immediately after handling error
        end
    end

    -- If no error is detected, proceed with normal display
    if not isError then
        local y = drawTitle(#lines, "Error") -- Example title
        for i = 1, #lines do
            drawCentrizedText(y, colorsText, lines[i]) -- Assuming draw function exists
            y = y + 1
        end
    end
end

do
	local handle, chunk = component.proxy(component.list("internet")() or error("Required internet component is missing")).request("https://raw.githubusercontent.com/ming736-2/MineOS/master/Installer/Main.lua")

	while true do
		chunk = handle.read(math.huge)
		
		if chunk then
			result = result .. chunk
		else
			break
		end
	end

	handle.close()
end

result, reason = load(result, "=installer")

if result then
	result, reason = xpcall(result, debug.traceback)

	if not result then
		error(reason)
	end
else
	error(reason)	
end