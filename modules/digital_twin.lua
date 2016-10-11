--digital twin functionality module

local virt_device_specification = {
  meta = {
    pid = nil,
    identifier = nil
  },
  state = {
    device = {
      control = nil,
      temperature = nil,
      tempset = nil,
      status = nil
    },
    cloud = {
      tempset = 80,
      control = 0
    },
    last_data = nil --timestamp of last data written
  },
  timeseries = {  --data to store in timeseries db
    temperature = true,
    tempset = true
  }
}

-- provides the key for look-up mapping of device in key-value and time-series
local function device_key(sn)
  if sn ~= nil and type(sn) == 'string' then
    return "device_" .. string.gsub(sn, ":", "") -- colons are not supported in KV db in Murano currently
  else
    return "device_unknown"
  end
end

-- Get Digital Twin of device or boot strap new
local function virt_dev(sn)
  local virtual_device = nil
  local devicekey = device_key(sn)

  local resp = Keystore.get({key = devicekey})

  if type(resp) == "table" and type(resp.value) == "string" then
    -- device has been created already. Get the latest state
    -- note that the device state is stored as a json string, convert to lua table
    virtual_device = from_json(resp.value)
  else
    -- bootstrap device table and store in key-value for fututure use
    virtual_device = virt_device_specification
    virtual_device.meta.identifier = sn
    --device.rid = lookup_rid(device.meta.pid, sn)
    local resp = Keystore.set({key = devicekey, value = to_json(virtual_device)})

  end

  return virtual_device
end

-- Update Virtual Device Digital Twin
local function virt_dev_update(sn, virtual_state)
  --update device state
  local resp = Keystore.set({key = device_key(sn), value = to_json(virtual_state)})
end


-- Digital Twin - Websocket Subscription
-- Open / Close websocket subscrtiption for a specific device
local function virt_dev_ws_subscriptions(sn,e)
  local websocket_id = tostring(e.socket_id) .. "/" .. tostring(e.server_ip)

  if e.type == "data" then
    return '{"type":"info","message":"messages from client not supported"}'
  elseif e.type == "open" then
    put_kv_list('subscribers_'..device_key(sn), websocket_id)
    print('ws open,'..tostring(websocket_id)..',device:'..tostring(sn))
    return '{"type":"info","message":"subscription open for device: '..tostring(sn)..'"}'
  elseif e.type == "close" then
    print('ws close,'..tostring(websocket_id))
    del_kv_list('subscribers_'..device_key(sn), websocket_id)

  end
end

-- Digital Twin - Websocket Publish
-- Will send data to any subscribers
local function virt_dev_ws_publish(sn, msg)
  -- get list of websockets currently subscribed
  local subscribers = get_kv_list('subscribers_'..device_key(sn))
  --print('ws:subscribers:'.. to_json(subscribers))

  -- send message to each subscriber
  for i,full_id in ipairs(subscribers) do
    --print('post-ws:subscriber:'..tostring(full_id))
    local socket_id, server_ip = string.match(full_id, '([^/]*)/([^/]*)')

    if socket_id ~= nil and server_ip ~= nil then
      Websocket.send({
        socket_id = socket_id,
        server_ip = server_ip,
        message = to_json(msg),
        type="data-text"
      })
    end
  end
end

-- Handle new packet of data from physical device
local function virt_dev_message_handler(sn, message)
  -- GET VIRTUAL INSTANCE OF DEVICE (WILL CREATE IF DOES NOT EXIST YET)
  local virtual_device = virt_dev(sn)

  if type(virtual_device) == "table" then

    -- UPDATE DEVICE VIRTUAL STATE / META
    virtual_device.meta.pid = message.pid or virtual_device.meta.pid
    virtual_device.last_data = message.timestamp/1000 or virtual_device.last_data
    virtual_device.state.device[message.alias] = message.value[2]
    virt_dev_update(sn, virtual_device)

    -- HANDLE TIMESERIES
    if virtual_device.timeseries[message.alias] then -- check if this is a resource that should be put into TS
      -- PUT DATA VALUE/TS INTO TIME SERIES DATABASE STORAGE:
      local ts_resp = Timeseries.write({
        query = message.alias .. ",identifier=" .. device_key(sn) .. " value=" .. message.value[2]
      })
    end
  else
    print('problem getting digital twin for:'..tostring(sn))
  end

  -- PUBLISH TO SUBSCRIBED WEBSOCKETS
  virt_dev_ws_publish(sn, '{"type":"data","device":"'.. sn .. '","resource":"'..message.alias..'","value":"'..tostring(message.value[2])..'","ts":'..message.timestamp..'}')

end

-- Write data to Digital Twin and to Physical Device
local function virt_device_cloud_write(sn, message)
  -- message format = {alias="alias",value=value}
  -- GET VIRTUAL INSTANCE OF DEVICE (WILL CREATE IF DOES NOT EXIST YET)
  local virtual_device = virt_dev(sn)
  print('cloud-write:'..sn..':'..to_json(message))

  if type(virtual_device) == "table" then

    -- WRITE TO PRODUCT SERVICE TO PUBLISH FOR DEVICE READ OR SUBSCRIPTION
    if virtual_device.meta.pid == nil then
      print('device digital twin no pid exists')
      return "device needs to send data first"
    end
    -- test
    local r = Device.write({
      pid=virtual_device.meta.pid,
      device_sn=sn,
      ['cloud_'..message.alias] = message.value
      })

    --print('device write response:'..to_json(r))

    -- UPDATE DEVICE VIRTUAL STATE / META
    virtual_device.state.cloud[message.alias] = message.value
    --print(to_json(virtual_device))
    virt_dev_update(sn, virtual_device)

    -- HANDLE TIMESERIES
    if virtual_device.timeseries['cloud_'..message.alias] then -- check if this is a resource that should be put into TS
      -- PUT DATA VALUE/TS INTO TIME SERIES DATABASE STORAGE:
      local ts_resp = Timeseries.write({
        query = message.alias .. ",identifier=" .. device_key(sn) .. " value=" .. message.value
      })
    end
  else
    print('device write failed to get device digital twin object')
  end

end

-- Digital Twin time-series data request
local function virt_dev_ts_query(sn, query_prefix, query_post)
  -- not doing much with this, could do more logic or checking
  local query_string =  query_prefix.." WHERE identifier = '"..device_key(sn).."' AND " .. query_post
  local resp = Timeseries.query({
    epoch='ms',
    q = query_string
  })
  return resp
end
