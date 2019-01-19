local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local producers = require "kong.plugins.charge-msg-produce.producers"
local cjson = require "cjson"
local cjson_encode = cjson.encode
local utils = require "kong.tools.utils"
local paths = require "kong.plugins.charge-msg-produce.paths"
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
  if conf.open_debug == 1 then
    ngx.log(ngx.ERR, " cache_key is ", conf.uuid)
  end
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
    kong.log.notice("creating a new Kafka Producer for cache key: ", cache_key)

    local err
    producer, err = producers.new(conf)
    if not producer then
      ngx.log(ngx.ERR, "[charge-log] failed to create a Kafka Producer for a given configuration: ", err)
      return
    end

    producers_cache[cache_key] = producer
  end

  -- send message 
  local ok, err = producer:send(conf.topic, nil, cjson_encode(message))
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
  ngx.log(ngx.NOTICE, " entry ", " charge plugins ")
  local request = ngx.req

  local msg = {}
  -- error access
  msg["cid"] = request.get_headers()["X-Consumer-Custom-ID"]

  if msg["cid"] == nil then
  	ngx.log(ngx.ERR, " invalid charge message ", " can not retrieve cid ")
  	return
  end

  -- no charge 1
  -- local fee = request.get_headers()["X-Custom-Fee"]
  -- if not fee or fee == false then
  --	return
  -- end

  -- no charge 2
  local uri = ngx.ctx.service.path -- ngx.var.request_uri or ""

  if conf.black_paths then
    for _, rule in ipairs(conf.black_paths) do
       if rule == uri then
       	 ngx.log(ngx.NOTICE, uri.." hit black path ","skip send charge message")
       	 return
       end
    end
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

    for k,v in ipairs(path_prod_table) do
      ngx.log(ngx.NOTICE, "key is "..k," value is "..v)
    end

    ngx.log(ngx.NOTICE, " old uri is ", uri)
    ngx.log(ngx.NOTICE, " test uri1 is ", path_prod_table["/a/284736964_120052353"])
    ngx.log(ngx.NOTICE, " test uri2 is ", path_prod_table["\\/a\\/284736964_120052353"])
    ngx.log(ngx.NOTICE, " test uri3 is ", path_prod_table[uri])
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

  local message = cjson_encode(msg)

  if conf.open_debug == 1 then
    ngx.log(ngx.NOTICE," charge message body ", message)
  end

  -- kafka producer support send async message why use ngx.timer.at function here? 
  local ok, err = ngx.timer.at(0, log, conf, message)
  if not ok then
    ngx.log(ngx.ERR, "[charge-log] failed to create timer: ", err)
  end
end

return ChargeMsgHandler
