local re_match = ngx.re.match

local bootstrap_server_regex = [[^([^:]+):(\d+)$]]

local path_prod_mappings_regex = [[^([^:]+):([^:]+)$]]

local _M = {}

--- Parses `host:port` string into a `{host: ..., port: ...}` table.
function _M.bootstrap_server(string)
  local m = re_match(string, bootstrap_server_regex, "jo")
  if not m then
    return nil, "invalid bootstrap server value: " .. string
  end
  return { host = m[1], port = m[2] }
end

-- check the string match  |path1:code|path2:code| 
function _M.valid_path_prod(string)
  local m = re_match(string, path_prod_mappings_regex, "jo")
  if not m then
    return false, "invalid path_prod_mappings value: " .. string
  end
  return true
end

--- Parses `path:code` string into a `{path:code}` table.
function _M.single_path_prod_table(string)
  local m = re_match(string, path_prod_mappings_regex, "jo")
  if not m then
    return nil, "invalid path_prod_mappings value: " .. string
  end
  local t = {}
  t[m[1]] = m[2]
  return t
end

return _M
