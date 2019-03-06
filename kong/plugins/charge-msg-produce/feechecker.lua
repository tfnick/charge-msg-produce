local _M = {}

--- need profit fee ?
function _M.isFee(feeHeader, ngx_headers)
  -- remove headers
  local fee = false
  if ngx_headers[feeHeader] ~= nil and ngx_headers[feeHeader] == "true" then
    fee =  true
  end
  return fee
end

--- project name in rulev2 which using for project fee
function _M.achieveProject(projectHeader, ngx_headers)
  -- remove headers
  local name = nil
  if ngx_headers[projectHeader] ~= nil and ngx_headers[projectHeader] ~= "" then
    name =  ngx_headers[projectHeader]
  end
  return name
end

return _M
