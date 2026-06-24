package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"
package.path  = package.path..";"..lfs.currentdir().."/Scripts/?.lua"
package.path = package.path ..";"..lfs.writedir() .. "Scripts\\?.lua"

local start_time = 0
local upstreamLuaExportStart = LuaExportStart
local upstreamLuaExportStop = LuaExportStop
local upstreamLuaExportAfterNextFrame = LuaExportAfterNextFrame
local upstreamLuaExportBeforeNextFrame = LuaExportBeforeNextFrame
local upstreamLuaExportActivityNextEvent = LuaExportActivityNextEvent

local isObjectExportAllowed = LoIsObjectExportAllowed()
local isSensorExportAllowed = LoIsSensorExportAllowed()
local isOwnshipExportAllowed = LoIsOwnshipExportAllowed()
local LOG_NAME = "MEASURE_PERFORMANCE"
local outputFile = nil
local lastName = nil
local prevPosition = nil
local traveledDistance = 0

local headerSeparator = ','
local rowSeparator = '\n'
local columnSeparator = ','
local columnOrder = {
	"modelTime",
	"normalizedTime",
	"aircraftType",
	"x",
	"y",
	"z",
	"pitch",
	"heading",
	"bank",
	"altitudeAboveSeaLevel",
	"trueAirSpeed",
	"indicatedAirSpeed",
	"trueAirSpeedKPH",
	"indicatedAirSpeedKPH",
	"verticalVelocity",
	"angleOfAttack",
	"accelerationUnits",
	"machNumber",
	--	"alt",
	"traveledDistance",
	"fuel_internal",
	"Temperature_Left",
	"Temperature_Right",
	"RPM_Left",
	"RPM_Right",
	"Fuel_Consuption_Left",
	"Fuel_Consuption_Right",
	"fuel_external",
	"hydraulicPressure_Left",
	"hydraulicPressure_Right",
	"Fuel_Consuption_Left",
	"Fuel_Consuption_Right",
}


local function readExportParameters()
	local selfData = LoGetSelfData()
	if selfData == nil then return nil end
	local modelTime = LoGetModelTime() - start_time
	local engineInfo = LoGetEngineInfo()
	local remaining = math.floor(modelTime)
	local miliseconds = modelTime - remaining
	local hours = math.floor(remaining / 3600)
	remaining = remaining % 3600
	local minutes = math.floor(remaining / 60)
	local seconds = (remaining % 60) + miliseconds
	local normalizedTime = string.format("2025-08-27T%02d:%02d:%012.9f+02:00", hours, minutes, seconds)
	local trueAirSpeed = LoGetTrueAirSpeed()
	local indicatedAirSpeed = LoGetIndicatedAirSpeed()
	local px = selfData.Position.x
	local py = selfData.Position.y
	local pz = selfData.Position.z
	if prevPosition ~= nil then
		local dx = px - prevPosition.x
		local dy = py - prevPosition.y
		local dz = pz - prevPosition.z
		traveledDistance = traveledDistance + math.sqrt(dx*dx + dy*dy + dz*dz)
	end
	prevPosition = { x = px, y = py, z = pz }

	return {
		-- https://wiki.hoggitworld.com/view/DCS_Export_Script
		selfData = 							selfData,
		pitch = 							selfData.Pitch,
		heading = 							selfData.Heading,
		x = 								selfData.Position.x,
		y = 								selfData.Position.y,
		z = 								selfData.Position.z,
		alt = 								selfData.LatLongAlt.Alt,
		bank =								selfData.Bank,
		aircraftType = 						selfData.GroupName,
		modelTime = 						modelTime,
		normalizedTime =					normalizedTime,
		fuel_external = 					engineInfo.fuel_external,
		Temperature_Left = 					engineInfo.Temperature.left,
		Temperature_Right = 				engineInfo.Temperature.right,
		RPM_Left = 							engineInfo.RPM.left,
		RPM_Right = 						engineInfo.RPM.right,
		Fuel_Consuption_Left = 				engineInfo.FuelConsumption.left,
		Fuel_Consuption_Right = 			engineInfo.FuelConsumption.right,
		fuel_internal = 					engineInfo.fuel_internal,
		hydraulicPressure_Left = 			engineInfo.HydraulicPressure.left,
		hydraulicPressure_Right = 			engineInfo.HydraulicPressure.right,
		altitudeAboveSeaLevel = 			LoGetAltitudeAboveSeaLevel(),
		trueAirSpeed = 						trueAirSpeed,
		indicatedAirSpeed = 				indicatedAirSpeed,
		trueAirSpeedKPH = 					trueAirSpeed * 3.6,
		indicatedAirSpeedKPH = 				indicatedAirSpeed * 3.6,
		verticalVelocity = 					LoGetVerticalVelocity(),
		angleOfAttack =						LoGetAngleOfAttack(),
		accelerationUnits = 				LoGetAccelerationUnits(),
		machNumber = 						LoGetMachNumber(),
		traveledDistance =					traveledDistance,
	}
end


local function writeParameters(params)
	local outputLine = ""
	for i, column in ipairs(columnOrder) do
		local v = params[column]
		if type(v) == "table" then
			for innerK, innerV in pairs(v) do
				if type(innerV) == "table" then
					for innerK2, innerV2 in pairs(innerV) do
						outputLine = outputLine..innerK2..";"
					end
					outputLine = outputLine..columnSeparator
				else
					outputLine = outputLine..innerV..columnSeparator
				end
			end
		else
			outputLine = outputLine..params[column]..columnSeparator
		end
	end
	-- log.write(LOG_NAME, log.INFO, "Writting: "..outputLine)
	outputFile:write(outputLine..rowSeparator)
end


local function writeHeader(params)
	local outputLine = ""
	for i, column in ipairs(columnOrder) do
		log.write(LOG_NAME, log.INFO, "Column: "..tostring(column))
		local v = params[column]
		if type(v) == "table" then
			for innerK, innerV in pairs(v) do
				outputLine = outputLine..column.."."..innerK..headerSeparator
			end
		else
			outputLine = outputLine..column..headerSeparator
		end
	end
	outputFile:write(outputLine..rowSeparator)
end

local function createOutputFile(params)
	if params.selfData == nil then return end
	local outputDirPath = getOutputDirPath()
	lfs.mkdir(outputDirPath)
	lastName = params.selfData.GroupName
	local filename = outputDirPath..[[\]]..lastName..".csv"
	log.write(LOG_NAME, log.INFO, "Output file: "..filename)

	outputFile = io.open(filename, "w")
	start_time = LoGetModelTime()
	prevPosition = nil
	traveledDistance = 0
	writeHeader(params)
end

local function closeFile()
	if outputFile then
		outputFile:close()
		outputFile = nil
		lastName = nil
		start_time = LoGetModelTime()
		prevPosition = nil
		traveledDistance = 0
	end
end

function getOutputDirPath()
	local result = lfs.writedir()..[[Telemetry\Default]]
	local missionPath = lfs.tempdir()..[[Mission\mission]]
	if lfs.attributes(missionPath) then
		log.write(LOG_NAME, log.INFO, "Mission file: "..missionPath)
		dofile(missionPath)
		mission_key = mission["sortie"]

		local dictionaryPath = lfs.tempdir()..[[Mission\l10n\DEFAULT\dictionary]]
		log.write(LOG_NAME, log.INFO, "Dictionary file: "..dictionaryPath)

		dofile(dictionaryPath)
		
		if dictionary[mission_key] ~= "" then
			result = lfs.writedir()..[[Telemetry\]]..dictionary[mission_key]
		end
	end
	return result
end

function LuaExportStart()
	
	
	-- call the upstream
	if upstreamLuaExportStart ~= nil then
			successful, err = pcall(upstreamLuaExportStart)
			if not successful then
					log.write(LOG_NAME, log.ERROR, "Error in upstream LuaExportStart function"..tostring(err))
			end
	end
	log.write(LOG_NAME, log.INFO, "LoIsObjectExportAllowed: "..tostring(isObjectExportAllowed))
	log.write(LOG_NAME, log.INFO, "LoIsSensorExportAllowed: "..tostring(isSensorExportAllowed))
	log.write(LOG_NAME, log.INFO, "LoIsOwnshipExportAllowed: "..tostring(isOwnshipExportAllowed))
	if isOwnshipExportAllowed then
		if outputFile == nil then
			local params = readExportParameters()
			if params ~= nil then
				if params.selfData then
					createOutputFile(params)
				end
			end
		end
	end
end

function LuaExportStop()
	-- call the upstream
	if upstreamLuaExportStop ~= nil then
			successful, err = pcall(upstreamLuaExportStop)
			if not successful then
					log.write(LOG_NAME, log.ERROR, "Error in upstream LuaExportStop function"..tostring(err))
			end
	end
	closeFile()
end

function LuaExportBeforeNextFrame()
	if upstreamLuaExportBeforeNextFrame ~= nil then
			successful, err = pcall(upstreamLuaExportBeforeNextFrame)
			if not successful then
				 log.write(LOG_NAME, log.ERROR, "Error in upstream LuaExportBeforeNextFrame function"..tostring(err))
			end
	end
end

function LuaExportAfterNextFrame()
	if upstreamLuaExportAfterNextFrame ~= nil then
			successful, err = pcall(upstreamLuaExportAfterNextFrame)
			if not successful then
					log.write(LOG_NAME, log.ERROR, "Error in upstream LuaExportAfterNextFrame function"..tostring(err))
			end
	end
end

function LuaExportActivityNextEvent(t)
	if upstreamLuaExportActivityNextEvent ~= nul then
		successful, err = pcall(upstreamLuaExportActivityNextEvent, t)
		if not successful then
			log.write(LOG_NAME, log.ERROR, "Error in upstream LuaExportAfterNextFrame function"..tostring(err))
		end
	end

	if isOwnshipExportAllowed then

		local params = readExportParameters()
		
		if params ~= nil then
			if outputFile == nil then
				local result, err = pcall(createOutputFile, params)
				if result == false then
					log.write(LOG_NAME, log.INFO, "Broken: "..err)
				end
			elseif params.selfData then
				if lastName ~= params.selfData.GroupName then
					closeFile()
					local result, err = pcall(createOutputFile, params)
					if result == false then
						log.write(LOG_NAME, log.INFO, "Broken: "..err)
					end
					params = readExportParameters()
				end
			end
			local result, err = pcall(writeParameters, params)
			if result == false then
				log.write(LOG_NAME, log.INFO, "Broken: "..err)
			end
		end
	end
	return t + 0.250
end
