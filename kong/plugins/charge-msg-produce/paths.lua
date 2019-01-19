local types = require "kong.plugins.charge-msg-produce.types"
local ipairs = ipairs

--- Creates a new path_code table
local function create_path_code_table(conf)
  local all_path_codes = {}
  for idx, value in ipairs(conf.path_prodcode_mappings) do
    ngx.log(ngx.NOTICE," singl key is ", idx)
    ngx.log(ngx.NOTICE," singl value is ", value)
    local single_path_code = types.single_path_prod_table(value)
    if not single_path_code then
      for k, v in ipairs(single_path_code)  do
        all_path_codes[k] = v
      end
    end
  end
  return all_path_codes
end

return { new = create_path_code_table }
