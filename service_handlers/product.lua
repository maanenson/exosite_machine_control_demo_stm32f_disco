--
-- Product Event Handler
-- Handle data events

-- PUBLISH DATA TO SUBSCRIBED WEBSOCKETS:
wsdebug('{"resource":"'..data.alias..'","value":"'..tostring(data.value[2])..'","ts":'..data.timestamp..'}')

--KEY VALUE currently does not accept colons, so incase device sn using MAC address, remove these
data.device_sn = string.gsub(data.device_sn, ":", "")

-- PUT SOME DATA INTO TIME SERIES DATABASE STORAGE:
if data.alias == "temperature" or data.alias == 'tempset' then
  local ts_resp = Timeseries.write({
    query = data.alias .. ",identifier=" .. data.device_sn .. " value=" .. data.value[2]
  })
end

-- PUT DATA INTO KEY VALUE STORE:
--
local resp = Keystore.get({key = "identifier_" .. data.device_sn})

-- Make sure each device has the following keys stored
local value = {
  temperature = "",
  uptime = "undefined",
  status = "undefined",
  tempset = "",
  control = ""
}
if type(resp) == "table" and type(resp.value) == "string" then
  value = from_json(resp.value) -- Decode from JSON to Lua Table
end
--]]

--local value = kv_read(data.device_sn)

-- Write data to virtual device table
value[data.alias] = data.value[2]

-- Add in other available data about this device / incoming data
value["timestamp"] = data.timestamp/1000 -- add server's timestamp
value["pid"] = data.vendor or data.pid

-- Intialize cloud variables for virtual device table (e.g. alerting data)
--[[
if value['alertstate'] == nil then
  value['alertstate'] = 0
end
if value['threshold'] == nil or value['threshold'] == 0  then
  value['threshold'] = 85
end
if value['contacts'] == nil or value['contacts'] == 0  then
  value['contacts'] = "+18577191066"
end
if value['lastalert'] == nil or value['lastalert'] == 0  then
  value['lastalert'] = os.time()
end

-- Handle Alerting
if data.alias == 'temperature' then
  --only send alerts if at least 10 seconds have gone by
  local curtime = os.time()
  if (curtime - tonumber(value['lastalert']) > 30) and value['contacts'] ~= "" then
    if tonumber(value['alertstate']) == 0 and tonumber(data.value[2]) >= value['threshold'] then
      --send alert
      local parameters = {
        To = value['contacts'],
        From = "+16123954687",
        Body = 'Temperature Alert, Device:'..tostring(data.device_sn)..',Temp: '..tostring(data.value[2])..'F'
      }
      response = Twilio.postMessage(parameters)
      value['lastalert'] = curtime
      value['alertstate'] = 1
    elseif tonumber(value['alertstate']) == 1 and tonumber(data.value[2]) < value['threshold'] then
      --send alert
      local parameters = {
        To = value['contacts'],
        From = "+16123954687",
        Body = 'Temperature Alert Resolved, Device:'..tostring(data.device_sn)..',Temp: '..tostring(data.value[2])..'F'
      }
      response = Twilio.postMessage(parameters)
      value['lastalert'] = curtime
      value['alertstate'] = 0
    else
      value['alertstate'] = 0
    end
  end
end
--]]

Keystore.set({key = "identifier_" .. data.device_sn, value = to_json(value)})
--kv_write(data.device_sn)
