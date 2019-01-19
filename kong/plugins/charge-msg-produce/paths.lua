local types = require "kong.plugins.charge-msg-produce.types"
local ipairs = ipairs

--- Creates a new path_code table
local function create_path_code_table(conf)
  local all_path_codes = {}
  for idx, value in ipairs(conf.path_prodcode_mappings) do
    ngx.log(ngx.NOTICE," singl key is ", idx)
    ngx.log(ngx.NOTICE," singl value is ", value)
    local k,v = types.single_path_prod_kv(value)
    if k ~= nil then
      all_path_codes[k] = v
    end
  end
  return all_path_codes
end

return { new = create_path_code_table }
