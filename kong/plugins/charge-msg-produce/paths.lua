local types = require "kong.plugins.charge-msg-produce.types"
local ipairs = ipairs

--- Creates a new path_code table
local function create_path_code_table(conf)
  local path_codes = {}
  for idx, value in ipairs(conf.path_prod_mappings) do
    local path_code_table = types.single_path_prod_table(value)
    if not path_code_table then
      return nil, "invalid single_path_prod_table value: " .. value

    else

      for k, v in ipairs(path_code_table)  do
        path_codes[k] = v
      end

    end
    return path_codes
  end
end

return { new = create_path_code_table }
