package = "charge-msg-produce"
version = "0.0.1-0"
source = {
   url = "git://github.com/tfnick/charge-msg-produce.git"
}
description = {
   summary = "This plugin sends request and response logs to Kafka.",
   license = "Apache 2.0"
}
dependencies = {
   "lua >= 5.1",
   "lua-resty-kafka >= 0.06"
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.charge-msg-produce.handler"] = "kong/plugins/charge-msg-produce/handler.lua",
      ["kong.plugins.charge-msg-produce.schema"] = "kong/plugins/charge-msg-produce/schema.lua",
      ["kong.plugins.charge-msg-produce.types"] = "kong/plugins/charge-msg-produce/types.lua",
      ["kong.plugins.charge-msg-produce.producers"] = "kong/plugins/charge-msg-produce/producers.lua",
   }
}
