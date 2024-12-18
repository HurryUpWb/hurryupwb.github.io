---
title: openresty的选型和应用
tags:
  - openresty
  - nginx
categories: 工作
abbrlink: 28213
date: 2024-12-13 17:31:29
---





## 背景

因为工作内容涉及到搭建一个Linux系统的镜像网站并提供公网服务，且该服务需要支持在设置了某个header的情况下发起对鉴权服务的调用，此处涉及到了一些逻辑判断，起初尝试使用Nginx来做，但是涉及到复杂的判断Nginx就不适合了，并且Nginx官方也不建议在配置中使用if做分支判断。

<!-- more -->



## 调研

因此针对上述原因，需要找到一个能满足如下要求的中间件

1. 能够提供高性能的HTTP服务
2. 能够支持稍微复杂的逻辑判断代码
3. 部署以及运维工作简单

针对上述需求，对比了几个常用的HTTP服务器，Nginx、Tomcat、Httpd、Apache等，由于原服务就是部署在Tomcat上，Tomcat对于Java环境的依赖以及XML的配置方式首先就被排除掉了，进一步了解业务发现，镜像服务最终提供的服务形式就是文件下载，所以最基础只需要将磁盘上的文件列表映射出来就可以了，考虑到对性能的需求，选择了Nginx。



## Nginx内的IF判断

使用Nginx对业务做迁移，过程中尝试在Nginx的conf文件内添加业务逻辑判断，即存在某个既定Header则做鉴权，不存在则只转发请求，第一个版本的代码如下

```nginx
location =/ {
    set $auth_id $http_auth_id;
    set $license $http_license;
    set $flag 0;
    if ($auth_id != ''){
        set $flag 1;
    }
    if ($license != ''){
        set $flag 1;
    }
    if ($flag = 1){
        //do auth
    }
    proxy_pass http://127.0.0.1/index.html;
}
```

经过测试发现上述代码经常达不到预期的效果，经过排查发现Nginx的IF条件语句和一般编程习惯的逻辑条件判断是不一样的，相关文档则有最著名的Nginx的官方文档[If is Evil](https://web.archive.org/web/20231227223503/https://www.nginx.com/resources/wiki/start/topics/depth/ifisevil/)，同时上述的多IF判断也让代码可读性变得很差和难以维护，针对IF的问题做了如下的测试：

![nginx-if指令测试](https://raw.githubusercontent.com/HurryUpWb/pics/main/image-20241218113152946.png)

显然可以发现，此处的IF使用逻辑是违背我们的日常编程习惯的，故针对这一问题搜索发现了OpenResty



## OpenResty与Nginx的对比

|           | **架构与扩展性** | **性能与资源使用** | **开发灵活性** | **社区与生态**     |
| --------- | ---------------- | ------------------ | -------------- | ------------------ |
| Nginx     | 低               | 高                 | 低             | 用户群体大、活跃   |
| OpenResty | 高               | 高                 | 高             | 用户群体小、不活跃 |

- Lua 脚本支持：通过 LuaJIT 提供高性能的脚本解释能力，允许在 Nginx 中嵌入 Lua 代码，实现灵活的请求处理逻辑。
- 集成的第三方模块：OpenResty 集成了许多有用的 Nginx 模块，如 ngx_lua、ngx_redis、ngx_memc 等，提供了丰富的功能。
- 高并发与高性能：继承了 Nginx 的高并发处理能力，同时 LuaJIT 提供了接近 C 语言的执行速度。
- 动态内容生成：适合需要实时生成动态内容的应用，如实时统计、动态 API 接口等。
- 扩展性强：通过 Lua 脚本可以灵活地扩展 Nginx 的功能，无需重新编译服务器。

简单概括就是Openresty继承了Nginx的能力并拓展了脚本化的支持。



## 应用

- 提供基础Http服务

- 添加鉴权逻辑判断，上述逻辑判断在引入Lua能力后代码可以改写成如下格式

  ```lua
  content_by_lua_block{
      if ngx.req.get_headers()["auth-id"] == nil then
              return ngx.exec("/index.html")
          else
              local res = ngx.location.capture("/authen")
              if res then
                  local res = res.body
                  ngx.print(res)
                  ngx.exit(200)
              end
          end
  }
  ```
