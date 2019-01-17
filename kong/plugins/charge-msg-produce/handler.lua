local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local producers = require "kong.plugins.charge-msg-produce.producers"
local cjson = require "cjson"
local cjson_encode = cjson.encode
local uuid = require 'resty.uuid'

local ChargeMsgHandler = BasePlugin:extend()

ChargeMsgHandler.PRIORITY = 5
ChargeMsgHandler.VERSION = "0.0.1"

local mt_cache = { __mode = "k" }
local producers_cache = setmetatable({}, mt_cache)

--- Computes a cache key for a given configuration.
local function cache_key(conf)
  -- here we rely on validation logic in schema that automatically assigns a unique id
  -- on every configuartion update
  if conf.open_debug == 1 then
    ngx.log(ngx.ERR, " cache_key ", conf.uuid)
  end
  return conf.uuid
end

--- Publishes a message to Kafka.
-- Must run in the context of `ngx.timer.at`.
local function log(premature, conf, message)
  if premature then
    return
  end

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

  local request = ngx.req

  local msg = {}

  msg["cid"] = request.get_headers()["X-Consumer-Custom-ID"]
  msg["uuid"] = uuid.generate()
  msg["path"] = ngx.ctx.service --ngx.var.request_uri or ""
  msg["reqt"] = ngx.var.request_time * 1000
  msg["rest"] = ngx.req.start_time() * 1000

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
