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

return _M
