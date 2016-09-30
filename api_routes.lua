--#ENDPOINT GET /development/test
return 'Hello World! \r\nI am a test Murano Solution API Route entpoint'

--#ENDPOINT GET /development/storage/keyvalue
-- Description: Show current key-value data for a specific unique device or for full solution
-- Parameters: ?identifier=<uniqueidentifier>
local identifier = tostring(request.parameters.identifier)

if identifier == 'all' or identifier == "nil" then
  local response_text = 'Getting Key Value Raw Data for: Full Solution: \r\n'
  local resp = Keystore.list()
  --response_text = response_text..'Solution Keys\r\n'..to_json(resp)..'\r\n'
  if resp['keys'] ~= nil then
    local num_keys = #resp['keys']
    local n = 1 --remember Lua Tables start at 1.
    while n <= num_keys do
      local id = resp['keys'][n]
      local response = Keystore.get({key = id})
      response_text = response_text..id..'\r\n'
      --response_text = response_text..'Data: '..to_json(response['value'])..'\r\n'
      -- print out each value on new line
      for key,val in pairs(from_json(response['value'])) do
        response_text = response_text.. '   '..key..' : '.. val ..'\r\n'
      end
      n = n + 1
    end
  end
  return response_text
else
  --local resp = Keystore.get({key = "identifier_" .. identifier})
  local identifier = "identifier_" .. string.gsub(request.body.identifier, ":", "")
  print(identifier)
  local resp = kv_read(identifier)
  return 'Getting Key Value Raw Data for: Device Identifier: '..identifier..'\r\n'..to_json(resp)
end

--#ENDPOINT GET /development/storage/timeseries
-- Description: Show current time-series data for a specific unique device
-- Parameters: ?identifier=<uniqueidentifier>
local identifier = tostring(request.parameters.identifier)
identifier = string.gsub(identifier, ":", "")

if tostring ~= nil and tostring ~= "" then
  local data = {}
  -- Assumes temperature and humidity data device resources
  out = Timeseries.query({
    epoch='ms',
    q = "SELECT value FROM temperature,humidity WHERE identifier = '" ..identifier.."' LIMIT 20"})
  data['timeseries'] = out

  return 'Getting Last 20 Time Series Raw Data Points for: '..identifier..'\r\n'..to_json(out)
else
  response.message = "Conflict - Identifier Incorrect"
  response.code = 404
  return
end


--#ENDPOINT GET /development/device/data
-- Description: Get timeseries data for specific device
-- Parameters: ?identifier=<uniqueidentifier>&window=<number>
local identifier = tostring(request.parameters.identifier) -- ?identifier=<uniqueidentifier>
identifier = string.gsub(identifier, ":", "")
local window = tostring(request.parameters.window) -- in minutes,if ?window=<number>
local getts = tonumber(request.parameters.getts) or 1
local getkv = tonumber(request.parameters.getkv) or 1
if true then
  local data = {}

  if getts == 1 then
    if window == nil then window = '60' end
    -- Assumes temperature and humidity data device resources
    local query_string = "SELECT value FROM temperature,tempset WHERE identifier = '"..identifier.."' AND time > now() - "..window.."m LIMIT 5000"
    --local query_string = "SELECT value FROM temperature WHERE time > now() - 6h AND time <= now() AND identifier = 'test' LIMIT 1000"
    --local query_string = "SELECT value FROM temperature WHERE identifier = '"..identifier.."' LIMIT 100"
    --print(query_string)
    local resp = Timeseries.query({
      epoch='ms',
      q = query_string
    })
    data['timeseries'] = resp
  end

  if getkv == 1 then
    local resp = {}
    resp = Keystore.get({key = "identifier_" .. identifier})
    data['keyvalue'] = resp
  end

  response.message = data
  response.code = 200

  return data
else
  response.message = "Conflict - Identifier Incorrect"
  response.code = 404
  return
end

--#ENDPOINT GET /development/derived
-- Description: Get timeseries data for specific device
-- Parameters: ?identifier=<uniqueidentifier>&window=<number>
local identifier = tostring(request.parameters.identifier) -- ?identifier=<uniqueidentifier>
identifier = string.gsub(identifier, ":", "")

local data = {}
-- https://docs.influxdata.com/influxdb/v0.13/query_language/functions/
local query_string = "SELECT MEDIAN(value), MEAN(value), MIN(value), MAX(value) FROM temperature WHERE time > now() - 1d AND time <= now() AND identifier = '"..identifier.."' GROUP BY time(1h)"
local out = Timeseries.query({
  epoch='ms',
  q = query_string
})
-- data.raw = out
local temp = {}
for i, row in ipairs(out.results[1].series[1].values) do
  temp[tostring(row[1])] = {
    ["median"] = row[2],
    ["mean"] = row[3],
    ["min"] = row[4],
    ["max"] = row[5],
  }
end
data[identifier] = {
  temperature = temp
}
return data

--#ENDPOINT POST /development/device
-- Description Sets threshold for device
-- Body: identifier=<uniqueid>&threshold=<threshold>&control=<control>&tempset=<tempset>

if request.body.identifier == nil then
  response.message = "Conflict - Identifier Incorrect"
  response.code = 404
else
  local identifier = "identifier_" .. string.gsub(request.body.identifier, ":", "")
  local resp = Keystore.get({key = identifier})

  if type(resp) == "table" and type(resp.value) == "string" then
    value = from_json(resp.value) -- Decode from JSON to Lua Table
  end

  if request.body.threshold then
    value['threshold'] = tonumber(request.body.threshold)
    device_write(request.body.identifier,'thresh',request.body.threshold)
  end

  if request.body.control and tonumber(request.body.control) >= 0 and tonumber(request.body.control) <= 1 then
    value['cloud_control'] = tonumber(request.body.control)
    device_write(request.body.identifier,'cloud_control',request.body.control)
  end

  if request.body.tempset and tonumber(request.body.tempset) >= 30 and tonumber(request.body.tempset) <= 120 then
    value['cloud_tempset'] = tonumber(request.body.tempset)
    device_write(request.body.identifier,'cloud_tempset',tonumber(request.body.tempset))
  end

  Keystore.set({key = identifier, value = to_json(value)})

  response.message = 'success'
  response.code = 200
end

return response


--#ENDPOINT POST /development/contact
-- Description Sets threshold for device
-- Body: {"identifier":<uniqueid>,"phonenumber":<phonenumber>}

if request.body.identifier == nil or request.body.phonenumber == nil then
  response.message = "Conflict - Parameters Incorrect"
  response.code = 404
else
  local identifier = "identifier_" .. string.gsub(request.body.identifier, ":", "")
  local resp = Keystore.get({key =identifier})

  if type(resp) == "table" and type(resp.value) == "string" then
    value = from_json(resp.value) -- Decode from JSON to Lua Table
  end

  value['contacts'] = tostring(request.body.phonenumber)
  Keystore.set({key = identifier, value = to_json(value)})

  response.message = 'success'
  response.code = 200
end

return response

--#ENDPOINT GET /keyvalueclean
-- Description: Show current key-value data for a specific unique device or for full solution
-- Parameters: ?device=<uniqueidentifier>
local resp = "not available"
local resp = Keystore.clear()
response.message = 'clearing keyvalue,'..to_json(resp)
response.code = 200
return response

--#ENDPOINT WEBSOCKET /realtime
return handle_debug_event(websocketInfo)
