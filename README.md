# Configuration-upload


### 设计思路 
  
  中间件将配置等信息统一上传至github代码仓库（以下统称为云端），中间件启动时，统一从云端拉取最新的配置信息，即应用中间件的配置信息也全部由云端进行统一纳管。
  
### 脚本思路

- 获取本机ip
- 获取本机中间件版本
- 判断本地是否存在配置文件
- 使用本地配置文件还是云端配置文件   (需增加配置)
- 下载云端文件到本地
  
  
### 遗留问题
  
  若云端代码仓库发生变更，则本地是否需要重启。满足何种情况可以触发更新？
  若为白天，是否需要 重新加载配置重启呢 ？

#### example
```
// 服务文件 
[root@master ~]# vim customservice.service
# copy to /usr/lib/systemd/system
# systemctl enable customservice.service
[Unit]
Description=customservice Service

[Service]
Type=forking
User=root
ExecStart=/etc/init.d/customservice.sh

[Install]
WantedBy=multi-user.target
```

``` 
// 启动文件
[root@master ~]#vim customservice.sh
#!/bin/bash
nohup /usr/bin/php /myproject/customservice.php >> /myproject/logs/customservice.log 2>&1 &
```


#### 其余介绍
1. 重载服务
`journalctl -f 服务名`
刚刚配置的服务需要让systemctl能识别，就必须刷新配置
`systemctl daemon-reload`
查看已启动的服务列表：`systemctl list-unit-files|grep enabled`
查看启动失败的服务列表：`systemctl --failed`

2. 启动/停止/重启我们的服务
刚刚建立好了我们的服务配置，现在就可以使用了！在此之前需要先使用下列命令让系统重新读取所有服务文件：

`systemctl daemon-reload`
然后通过以下命令操控服务：

启动服务
`service 服务名 start`

终止服务
`service 服务名 stop`

重启服务

`service 服务名 restart`

那么注意服务名就是我们刚刚创建的服务配置文件service文件的文件名（不包括扩展名），例如我的服务文件是redis-server.service，那么我的服务名是redis-server。

其实我们执行启动服务命令时，就会执行我们刚刚配置文件中ExecStart的值的命令，同样终止、重启会对应执行配置文件中ExecStop、ExecReload的值的命令。
```
