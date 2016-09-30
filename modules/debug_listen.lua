-- debug websocket listener

function handle_debug_event(e)
  local full_id = tostring(e.socket_id) .. "/" .. tostring(e.server_ip)

  if e.type == "data" then
    return "messages from client not supported"
  elseif e.type == "open" then
    put_kv_list("debug_subscribers", full_id)
    print('open,'..tostring(full_id))
    return "Debug Log Attached"
  elseif e.type == "close" then
    print('close,'..tostring(full_id))
    del_kv_list("debug_subscribers", full_id)
  end
end

function wsdebug(msg)
  -- get list of websockets currently subscribed
  local subscribers = get_kv_list("debug_subscribers")
  --print('new message')

  -- send message to each subscriber
  for i,full_id in ipairs(subscribers) do
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
