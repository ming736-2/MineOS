
local
	stringsMineOSEFI,
	stringsChangeLabel,
	stringsKeyDown,
	stringsComponentAdded,
	stringsFilesystem,
	stringsURLBoot,
	
	componentProxy,
	componentList,
	pullSignal,
	uptime,
	tableInsert,
	mathMax,
	mathMin,
	mathHuge,
	mathFloor,

	colorsTitle,
	colorsBackground,
	colorsText,
	colorsSelectionBackground,
	colorsSelectionText,

	OSList,
	bindGPUToScreen,
	drawRectangle,
	drawText,
	newMenuElement,
	drawCentrizedText,
	drawTitle,
	status,
	executeString,
	boot,
	newMenuBackElement,
	menu,
	input,
	internetExecute =

	"MineOS EFI",
	"Change label",
	"key_down",
	"component_added",
	"filesystem",
	"URL boot",

	component.proxy,
	component.list,
	computer.pullSignal,
	computer.uptime,
	table.insert,
	math.max,
	math.min,
	math.huge,
	math.floor,

	0x2D2D2D,
	0xE1E1E1,
	0x878787,
	0x878787,
	0xE1E1E1

local
	eeprom,
	gpu,
	internetAddress =

	componentProxy(componentList("eeprom")()),
	componentProxy(componentList("gpu")()),
	componentList("internet")()

local
	gpuSet,
	gpuSetBackground,
	gpuFill,
	eepromSetData,
	eepromGetData,
	screenWidth, 
	screenHeight =

	gpu.set,
	gpu.setBackground,
	gpu.fill,
	eeprom.setData,
	eeprom.getData

OSList,
bindGPUToScreen,
drawRectangle,
drawText,
newMenuElement,
drawCentrizedText,
drawTitle,
status,
executeString,
boot,
newMenuBackElement,
menu,
input,
internetExecute =

{
	{
		"/OS.lua"
	},
	{
		"/init.lua",
		function()
			computer.getBootAddress, computer.setBootAddress = eepromGetData, eepromSetData
		end
	}
},

function()
	local screenAddress = componentList("screen")()
	
	if screenAddress then
		gpu.bind(screenAddress, true)
		screenWidth, screenHeight = gpu.getResolution()
	end
end,

function(x, y, width, height, color)
	gpuSetBackground(color)
	gpuFill(x, y, width, height, " ")
end,

function(x, y, foreground, text)
	gpu.setForeground(foreground)
	gpuSet(x, y, text)
end,

function(text, callback, breakLoop)
	return {
		s = text,
		c = callback,
		b = breakLoop
	}
end,

function(y, foreground, text)
	drawText(mathFloor(screenWidth / 2 - #text / 2), y, foreground, text)
end,

function(y, title)
	y = mathFloor(screenHeight / 2 - y / 2)
	drawRectangle(1, 1, screenWidth, screenHeight, colorsBackground)
	drawCentrizedText(y, colorsTitle, title)

	return y + 2
end,

function(statusText, needWait)
    local lines = {}

    -- Split `statusText` into lines and replace tabs with spaces
    for line in statusText:gmatch("[^\n]+") do
        lines[#lines + 1] = line:gsub("\t", "  ")
    end

    -- Define error mappings
    local errs = {
        ["NO_SUCH_COMPONENT"] = {"no such component", 0x00000001},
        ["OUT_OF_MEMORY"] = {"not enough memory", 0x00000002},
        ["INACCESSIBLE_BOOT_DEVICE"] = {"No boot sources found", 0x00000003}
    }

    -- Check for errors in each line
    local isError = false
    local errorCode = nil

    for i = 1, #lines do
        for key, value in pairs(errs) do
            if string.find(lines[i], value[1]) then
                isError = true
                errorCode = value[2]
                break
            end
        end
        if isError then
            -- Handle error display with blue background
            gpuSetBackground(0x0000FF)  -- Set background color to blue
            local y = drawTitle(#lines, "An error has occurred")
            for j = 1, #lines do
                drawCentrizedText(y, 0xFFFFFF, lines[j])  -- White text color
                y = y + 1
            end
            return  -- Exit the function immediately after handling error
        end
    end

    -- If no error is detected, proceed with normal display
    if not isError then
        local y = drawTitle(#lines, "Normal Display") -- Example title
        for i = 1, #lines do
            drawCentrizedText(y, colorsText, lines[i]) -- Assuming draw function exists
            y = y + 1
        end

        -- Optionally wait for a key press if `needWait` is true
        if needWait then
            while pullSignal() ~= stringsKeyDown do
                -- Wait until the specified key is pressed
            end
        end
    end
end,

function(...)
	local result, reason = load(...)

	if result then
		result, reason = xpcall(result, debug.traceback)

		if result then
			return
		end
	end

	status(reason, 1)
end,

function(proxy)
	local OS

	for i = 1, #OSList do
		OS = OSList[i]

		if proxy.exists(OS[1]) then
			status("Booting from " .. (proxy.getLabel() or proxy.address))

			-- Updating current EEPROM boot address if it's differs from given proxy address
			if eepromGetData() ~= proxy.address then
				eepromSetData(proxy.address)
			end

			-- Running OS pre-boot function
			if OS[2] then
				OS[2]()
			end

			-- Reading boot file
			local handle, data, chunk, success, reason = proxy.open(OS[1], "rb"), ""

			repeat
				chunk = proxy.read(handle, mathHuge)
				data = data .. (chunk or "")
			until not chunk

			proxy.close(handle)

			-- Running boot file
			executeString(data, "=" .. OS[1])

			return 1
		end
	end
end,

function(f)
	return newMenuElement("Back", f, 1)
end,

function(title, items)
	local selectedIndex = 1

	while 1 do
		local y, x, text, e = drawTitle(#items + 2, title)
		
		for i = 1, #items do
			text = "  " .. items[i].s .. "  "
			x = mathFloor(screenWidth / 2 - #text / 2)
			
			if i == selectedIndex then
				gpuSetBackground(colorsSelectionBackground)
				drawText(x, y, colorsSelectionText, text)
				gpuSetBackground(colorsBackground)
			else
				drawText(x, y, colorsText, text)
			end
			
			y = y + 1
		end

		e = { pullSignal() }

		if e[1] == stringsKeyDown then
			if e[4] == 200 and selectedIndex > 1 then
				selectedIndex = selectedIndex - 1
			
			elseif e[4] == 208 and selectedIndex < #items then
				selectedIndex = selectedIndex + 1
			
			elseif e[4] == 28 then
				if items[selectedIndex].c then
					items[selectedIndex].c()
				end
				
				if items[selectedIndex].b then
					break
				end
			end
		elseif e[1] == stringsComponentAdded and e[3] == "screen" then
			bindGPUToScreen()
		end
	end
end,

function(title, prefix)
	local
		y,
		text,
		state,
		prefixedText,
		char,
		e =

		drawTitle(2, title),
		"",
		1

	while 1 do
		prefixedText = prefix .. text

		gpuFill(1, y, screenWidth, 1, " ")
		drawCentrizedText(y, colorsText, prefixedText .. (state and "_" or ""))

		e = { pullSignal(0.5) }

		if e[1] == stringsKeyDown then
			if e[4] == 28 then
				return text

			elseif e[4] == 14 then
				text = text:sub(1, -2)
			
			else
				char = unicode.char(e[3])

				if char:match("^[%w%d%p%s]+") then
					text = text .. char
				end
			end

			state = 1
		
		elseif e[1] == "clipboard" then
			text = text .. e[3]
		
		elseif not e[1] then
			state = not state
		end
	end
end,

function(url)
	local
		connection,
		data,
		result,
		reason =

		componentProxy(internetAddress).request(url),
		""

	if connection then
		status("Downloading script")

		while 1 do
			result, reason = connection.read(mathHuge)	
			
			if result then
				data = data .. result
			else
				connection.close()
				
				if reason then
					status(reason, 1)
				else
					executeString(data, "=url")
				end

				break
			end
		end
	else
		status("Invalid URL", 1)
	end
end

bindGPUToScreen()
status("Hold Alt to show boot options")

-- Waiting 1 sec for user to press Alt key
local deadline, eventData = uptime() + 1

while uptime() < deadline do
	eventData = { pullSignal(deadline - uptime()) }

	if eventData[1] == stringsKeyDown and eventData[4] == 56 then
		local utilities = {
			newMenuElement("Disk utility", function()
				local
					restrict,
					filesystems =
					
					function(text, limit)
						return (#text < limit and text .. string.rep(" ", limit - #text) or text:sub(1, limit)) .. "   "
					end,
					{ newMenuBackElement() }

				local function updateFilesystems()
					for i = 2, #filesystems do
						table.remove(filesystems, 1)
					end

					for address in componentList(stringsFilesystem) do
						local proxy = componentProxy(address)

						local
							label,
							isReadOnly =

							proxy.getLabel() or "Unnamed",
							proxy.isReadOnly()

						tableInsert(filesystems, 1,
							newMenuElement(
								(address == eepromGetData() and "> " or "  ") ..
								restrict(label, 10) ..
								restrict(proxy.spaceTotal() > 1048575 and "HDD" or proxy.spaceTotal() > 65535 and "FDD" or "SYS", 3) ..
								restrict(isReadOnly and "R  " or "R/W", 3) ..
								restrict(math.ceil(proxy.spaceUsed() / proxy.spaceTotal() * 100) .. "%", 4) ..
								address:sub(1, 8) .. "…",
								
								function()
									local elements = {
										newMenuElement(
											"Set as bootable",
											function()
												eepromSetData(address)
												updateFilesystems()
											end,
											1
										),

										newMenuBackElement()
									}

									if not isReadOnly then
										tableInsert(elements, 2, newMenuElement(
											stringsChangeLabel,
											function()
												pcall(proxy.setLabel, input(stringsChangeLabel, "New value: "))
												updateFilesystems()
											end,
											1
										))

										tableInsert(elements, 3, newMenuElement(
											"Erase",
											function()
												status("Erasing " .. address)
												proxy.remove("")
												updateFilesystems()
											end,
											1
										))
									end

									menu(label .. " (" .. address .. ")", elements)
								end
							)
						)
					end
				end

				updateFilesystems()
				menu("Select filesystem", filesystems)
			end),

			newMenuBackElement()
		}

		if internetAddress then	
			tableInsert(utilities, 2, newMenuElement("System recovery", function()
				internetExecute("https://tinyurl.com/29urhz7z")
			end))
			
			tableInsert(utilities, 3, newMenuElement(stringsURLBoot, function()
				internetExecute(input(stringsURLBoot, "Address: "))
			end))
		end

		menu(stringsMineOSEFI, utilities)
	end
end

-- Trying to boot from previously selected fs or from any available
local bootProxy = componentProxy(eepromGetData())

if not (bootProxy and boot(bootProxy)) then
	local function tryBootFromAny()
		for address in componentList(stringsFilesystem) do
			bootProxy = componentProxy(address)

			if boot(bootProxy) then
				computer.shutdown()
			else
				bootProxy = nil
			end
		end

		if not bootProxy then
			status("No boot sources found")
		end
	end

	tryBootFromAny()

	-- Waiting for any fs component available
	while 1 do
		if pullSignal() == stringsComponentAdded then
			tryBootFromAny()
		end
	end
end