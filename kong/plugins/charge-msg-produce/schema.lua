local types = require "kong.plugins.charge-msg-produce.types"
local utils = require "kong.tools.utils"

--- Validates value of `bootstrap_servers` field.
local function check_bootstrap_servers(values)
  if values and 0 < #values then
    for _, value in ipairs(values) do
      local server = types.bootstrap_server(value)
      if not server then
        return false, "invalid bootstrap server value: " .. value
      end
    end
    return true
  end
  return false, "bootstrap_servers is required"
end

local function check_black_paths(values)
  if values and 0 < #values then
    for _, value in ipairs(values) do
      if not value or value == nil then
        return false, "invalid black_paths : " .. value
      end
    end
    return true
  end
  return true
end


local function check_path_prodcode_mappings(values)
  if values and 0 < #values then
    for _, value in ipairs(values) do
      local single_path_prod = types.single_path_prod_table(value)
      if not single_path_prod then
        return false, "invalid path_prodcode_mappings value: " .. value
      end
    end
    return true
  end
  return true
end

--- (Re)assigns a unique id on every configuration update.
-- since `uuid` is not a part of the `fields`, clients won't be able to change it
local function regenerate_uuid(schema, plugin_t, dao, is_updating)
  plugin_t.uuid = utils.uuid()
  return true
end

return {
  fields = {
    open_debug = {type = "number", default = 0}, -- 0 close 1 open
    bootstrap_servers = { type = "array", required = true, func = check_bootstrap_servers },
    topic = { type = "string", required = true },
    timeout = { type = "number", default = 10000 },
    keepalive = { type = "number", default = 60000 },
    producer_request_acks = { type = "number", default = 1, enum = { -1, 0, 1 } },
    producer_request_timeout = { type = "number", default = 2000 },
    producer_request_limits_messages_per_request = { type = "number", default = 200 },
    producer_request_limits_bytes_per_request = { type = "number", default = 1048576 },
    producer_request_retries_max_attempts = { type = "number", default = 10 },
    producer_request_retries_backoff_timeout = { type = "number", default = 100 },
    producer_async = { type = "boolean", default = true },
    producer_async_flush_timeout = { type = "number", default = 1000 },
    producer_async_buffering_limits_messages_in_memory = { type = "number", default = 50000 },
    black_paths = {type = "array", func = check_black_paths},
    -- define multi version service url to one product code if need
    path_prodcode_mappings = {type = "array", func = check_path_prodcode_mappings},
  },
  self_check = regenerate_uuid,
}
