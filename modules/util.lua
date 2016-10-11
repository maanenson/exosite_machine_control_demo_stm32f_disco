

--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[

 Set Helpers

--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]
function get_kv_set(key)
  local resp = Keystore.command{key = key, command = "smembers"}
  return resp.value
end

function put_kv_set(key, member)
  local resp = Keystore.command{key = key, command = "sadd", args = {member}}
  return resp
end

function del_kv_set(key, member)
  local resp = Keystore.command{key = key, command = "srem", args = {member}}
  return resp
end

--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[--[[

 List Helpers

--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]--]]
function get_kv_list(key)
  local resp = Keystore.command{key = key, command = "lrange", args = {0,-1}}
  return resp.value
end

function put_kv_list(key, member)
  local resp = Keystore.command{key = key, command = "lpush", args = {member}}
  return resp
end

function del_kv_list(key, member)
  local resp = Keystore.command{key = key, command = "lrem", args = {0, member}}
  return resp
end
