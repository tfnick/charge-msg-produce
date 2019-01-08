
### 插件顺序

jwt-header-rewrite -> jwt | sign-verify -> quota-check -> charge-msg-produce

### 插件级别

jwt-header-rewrite(global) -> jwt | sign-verify(route) -> quota-check(route) -> charge-msg-produce(route)


### quota-check主要功能

基于全局共享缓存ngx-sharr-DICT实现，当计费系统发现账户余额不足，调用网关的admin-api更新数据库以及全局缓存，实现客户quota不足的访问控制


### jwt-header-rewrite主要功能

将吉荣数网关的定制jwtToken转换为kong中的Bearer类型表示比如

```
Content-TOKEN:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJkOTg0ZDg5MDMzZmE0MDE0OTQ2YThhYTE4MjA5NDc1YiIsImV4cCI6MTU0ODE3NTU2Nn0.mRPVYmGS0l9ZCA-i28PA9JCi_vkKRqzpr6vno-Sd69U

```
表示为：

```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJkOTg0ZDg5MDMzZmE0MDE0OTQ2YThhYTE4MjA5NDc1YiIsImV4cCI6MTU0ODE3NTU2Nn0.mRPVYmGS0l9ZCA-i28PA9JCi_vkKRqzpr6vno-Sd69U

```
即：Authorization: Bearer <token> 的表示形式


### sign签名验证

实现老接口的sign签名方法，兼容老接口

### charge-msg-produce

基于kafka 发送计费消息，实现网关统一的计费.



### 插件安装过程

git clone https://github.com/tfnick/jwt-header-rewrite.git

cd jwt-header-rewrite

luarocks install jwt-header-rewrite-1.0-0.rockspec

> setup location check after install

```

/usr/local/share/lua/5.1/kong/plugins/jwt-header-rewrite

```

> 重启kong

kong restart / reload

> 通过Kong Admin Api检查插件是否已经启用

curl 127.0.0.1:8001/plugins/enabled 2>/dev/null |python -m json.tool


> 测试插件是否起作用

```
curl -H "Content-TOKEN:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJkMlN6emVoWWM1ODdxM1ZlWjVlU2FaTFdwSXhOaUFUbSIsImV4cCI6MTU0NzAyNzg4M30.hEZweYlX8nG4Vm5AFWBg-Bqg-G3rp33VjgsqCDLFsQs" 192.168.1.195:8000/jwt

```

> kong日志目录

```

/usr/local/kong/logs

```

> kong jwt plugin return

```
{"exp":"token expired"}
```

服务端需要设置一个更长的token有效期
```
{"exp":"exceeds maximum allowed expiration"}

```

header 传递

```

Upstream Headers
When a JWT is valid, a Consumer has been authenticated, the plugin will append some headers to the request before proxying it to the upstream service, so that you can identify the Consumer in your code:

X-Consumer-ID, the ID of the Consumer on Kong
X-Consumer-Custom-ID, the custom_id of the Consumer (if set)
X-Consumer-Username, the username of the Consumer (if set)
X-Anonymous-Consumer, will be set to true when authentication failed, and the ‘anonymous’ consumer was set instead.

```

