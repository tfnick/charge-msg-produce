local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local producers = require "kong.plugins.charge-msg-produce.producers"
local cjson = require "cjson"
local cjson_encode = cjson.encode
local utils = require "kong.tools.utils"
local paths = require "kong.plugins.charge-msg-produce.paths"
local fee_checker = require "kong.plugins.charge-msg-produce.feechecker"
local ipairs = ipairs
local ChargeMsgHandler = BasePlugin:extend()

ChargeMsgHandler.PRIORITY = 5
ChargeMsgHandler.VERSION = "0.0.1"

local producers_cache = setmetatable({}, { __mode = "k" })
-- per-worker cache of matched UAs
-- we use a weak table, index by the `conf` parameter, so once the plugin config
-- is GC'ed, the cache follows automatically
-- conf -> table
local path_prod_cache = setmetatable({}, { __mode = "k" })


--- Computes a cache key for a given configuration.
local function cache_key(conf)
  -- here we rely on validation logic in schema that automatically assigns a unique id
  -- on every configuartion update
  return conf.uuid
end

--- Publishes a message to Kafka.
-- Must run in the context of `ngx.timer.at`.
local function log(premature, conf, message)
  if premature then
    return
  end

  -- get produce from cache
  local cache_key = cache_key(conf)
  if not cache_key then
    ngx.log(ngx.ERR, "[charge-log] cannot log a given request because configuration has no uuid")
    return
  end

  local producer = producers_cache[cache_key]
  if not producer then
    ngx.log(ngx.NOTICE,"creating a new Kafka Producer for cache key: ", cache_key)

    local err
    producer, err = producers.new(conf)
    if not producer then
      ngx.log(ngx.ERR, "[charge-log] failed to create a Kafka Producer for a given configuration: ", err)
      return
    end

    producers_cache[cache_key] = producer
  end

  -- send message 
  local final_msg, n, err = ngx.re.gsub(cjson_encode(message), [[\\/]], [[/]])
  local ok, err = producer:send(conf.topic, nil, final_msg)
  if not ok then
    ngx.log(ngx.ERR, "[charge-log] failed to send a message on topic ", conf.topic, ": ", err)
    return
  end
end

function ChargeMsgHandler:new()
  ChargeMsgHandler.super.new(self, "charge-msg-produce")
end

function ChargeMsgHandler:log(conf, other)
  ChargeMsgHandler.super.log(self)
  local request = ngx.req

  -- no charge 2
  local uri = ngx.ctx.service.path -- ngx.var.request_uri or ""
  local uri2 = ngx.var.request_uri or ""

  ngx.log(ngx.NOTICE, "path1", uri)
  ngx.log(ngx.NOTICE, "path2", uri2)

  local msg = {}
  -- error access
  msg["cid"] = request.get_headers()["X-Consumer-Custom-ID"]

  if msg["cid"] == nil then
  	ngx.log(ngx.ERR, " invalid charge message ", " can not retrieve cid "..uri)
  	return
  end

  -- no charge 1
  local fee = fee_checker.isFee("X-Custom-Fee",ngx.header)
  if fee then
    -- nothing
  else
    return
  end



  if conf.black_paths then
    for _, rule in ipairs(conf.black_paths) do
       if rule == uri then
       	 -- ngx.log(ngx.NOTICE, uri.." hit black path ","skip send charge message")
       	 return
       end
    end
  end

  local project = fee_checker.achieveProject("X-Custom-Project",ngx.header)

  -- assemble uri/projectName as the final fee path
  if project ~= nil then
    uri = uri.."/"..project
  end
  
  -- get path_prod table from cache
  if conf.path_prodcode_mappings ~= nil then
    local path_prod_table = path_prod_cache[cache_key]
    if not path_prod_table  then
      kong.log.notice("creating a new path_prod_table for cache key: ", cache_key)

      path_prod_table = paths.new(conf)

      if not path_prod_table then
        ngx.log(ngx.ERR, "[charge-log] failed to create a path_prod_table for a given configuration: ", err)
      else
        path_prod_cache[cache_key] = path_prod_table
      end
    end

    if path_prod_table and path_prod_table[uri] ~= nil then 
      if conf.open_debug == 1 then
        ngx.log(ngx.NOTICE, " mapping charge path "..uri," to "..path_prod_table[uri])
      end
      uri = path_prod_table[uri]
    end
  end 
  

  msg["uuid"] = request.get_headers()["Kong-Request-ID"] or utils.uuid()
  msg["path"] = uri --ngx.var.request_uri or ""
  msg["reqt"] = ngx.req.start_time() * 1000
  msg["rest"] = msg["reqt"] + ngx.var.request_time * 1000

  if conf.open_debug == 1 then
    local message, n, err = ngx.re.gsub(cjson_encode(msg), [[\\/]], [[/]])
    ngx.log(ngx.NOTICE," charge message body ", message)
  end

  -- kafka producer support send async message why use ngx.timer.at function here? 
  local ok, err = ngx.timer.at(0, log, conf, msg)
  if not ok then
    ngx.log(ngx.ERR, "[charge-log] failed to create timer: ", err)
  end
end

return ChargeMsgHandler
