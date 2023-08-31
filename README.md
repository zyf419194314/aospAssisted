# AOSP源码辅助脚本

## 简介
该脚本用于辅助国内开发者进行AOSP源码的下载、编译、汇入等操作，目前支持以下功能
- AOSP源码下载(基于中科大源)
- AOSP源码编译(基于最新安卓源码的 Cuttlefish lunch)
- AOSP gerrit源码仓库创建
- AOSP gerrit源码汇入
- AOSP gerrit源码删除

关联教程有：
- [Android源码编译教程与排错指南](https://juejin.cn/post/7043063280704684063)
- [如何完整的将AOSP源码汇入本地gerrit](https://juejin.cn/post/7251521076994555962)

## 配置文件参数列表
| 参数 | 描述 |
| --- | --- |
| DIR | AOSP源码存放路径 |
| GERRIT_DEPLOY_TYPE | gerrit部署方式 1 测试环境部署 / 2 正式环境部署 |
| GERRIT_DEPLOY_VERSION | gerrit部署版本 |
| GERRIT_DEPLOY_PORT | gerrit部署端口 |
| GERRIT_SERVER_IP | gerrit服务器地址 |
| GERRIT_SERVER_PORT | gerrit服务器端口 |
| GERRIT_SERVER_USERNAME | gerrit用户名 |
| GERRIT_MANIFEST_XML_FILE | repo manifest xml 文件 | 
| REPO_BRANCH | AOSP源码repo分支 |
| GERRIT_SERVER_PROTOCOL | gerrit使用的协议 |
| LUNCH_TARGET | AOSP lunch 类型 |

## 文件结构
```
├── aosp_build.sh           # aosp源码编译(基于Cuttlefish)
├── aosp_download.sh        # aosp源码下载
├── config.sh               # 配置文件功能
├── gerrit_create.sh        # 创建geerit仓库
├── gerrit_delete.sh        # 删除geerit仓库
├── gerrit_push.sh          # push aosp源码到gerrit
├── main.sh                 # 总文件入口
└── README.md               # 自述文件
```