---
title: 使用 Zabbix 监控 Exchange Server 的数据库
date: 2019-03-17 00:12:06
toc: true
categories: Moniting
thumbnail: https://i.imgur.com/f7BvyQJ.png
---
在这篇文章里我想要分享一下 Exchange Server 2016 数据库状态以及数据库使用量的监控方法，经过几次修改和迭代，目前我使用的是 Zabbix 3.2 对数据库进行统一、自动化、动态自配置的监控。

## 主要解决了哪些问题？

当前主流的监控平台，如 Zabbix、Prometheus，微软自家的 SCOM，还有古董 Cacti 我都已经进行过或多或少的尝试，最终选定 Zabbix 作为 Exchange Server 的统一监控平台，主要原因是它高自由度的配置、分布式部署方式以及丰富的 API 接口，便于针对性的修改和获取数据用于统一展示，图表功能一般但是够用，好在可以通过 API 将数据取出来做二次处理。

在花费了大量时间优化调整监控项、触发器以及告警策略之后，只剩最后一块难啃的石头，也就是今天讨论的数据库状态监控。

## Exchange 数据库监控的演变

集团 Exchange 数据库的监控经历了 3 个主要阶段：
* 最初是根据一个数据库列表文档跑脚本，通过 `Test-MAPIConnectivity` 检测数据库是否挂载，发送短信来告警。手工维护难免造成遗漏；
* 在经历了一个由于主备关系问题导致的集群崩溃事故之后，第二阶段的脚本使用 `Get-MailboxDatabaseCopyStatus` 来侦测数据库状态。另外可以自动的检测新加入的数据库；
* 但是数据库大小、人数、可用空间、主备关系这些东西没有直观的展示出来，于是进化到第三阶段，Zabbix 统一监控展示。

## Zabbix 监控数据库思路

目前所有的邮件服务器均已加入 Zabbix 做基础的硬件信息和服务、性能指标的监控。

使用 Zabbix 发现服务，通过一个 Powershell 脚本( `Get-ExchangeDBDiscovery.ps1` )获取到每台服务器中的数据库信息，写入到服务器监控项中；为了减少抓取延迟，服务器本地每分钟会执行另一个 Powershell 脚本(`Get-ExchangeDBStatus.ps1`)，将所需要的数据库信息全部写入到脚本执行目录中的子目录 `DBStatus` 中；Zabbix 中的服务器，通过执行自定义命令从 CSV 文件中获取字段值，完成数据收集；如果数据库被卸载，则触发一级告警，直接电话通知我。若数据库同步状态异常，则触发二级告警，使用集团内部 IM 软件告诉我。

### 困难

由于我的目标是做成全自动监控，而且数据库数量实在太多（集团接近 50000 人，分了 300 多个数据库）所以其中比较困难的点在于：

1. 由于数据库分 Active 和 Passive，会在两台成对的服务器中各生成一个监控项，降低 Zabbix 执行效率，所以必须分开
2. 由于 Active 和 Passive 会切换，如果监控项也跟着切换，会造成临时性数据获取失败
3. 主备关系切换同样会导致挂载信息和复制信息的混乱

### 解决方案

对于第一点和第二点，通过 `Get-MailboxDatabaseCopyStatus` 中数据库挂载优先级字段 `ActivationPreference` 将主备关系固定，去掉优先级是 2 的数据库。

对于第三点，使用了一个过滤方法 `Get-MailboxDatabaseCopyStatus | Where {$_.status -like "*ount*"}` ,`ount` 是 Active 的数据库可能的四种状态：`Mounted`、`Dismounted`、`Mounting`、`Dismounting`。

## 源码使用方法

源码我已经放在了 GitHub，使用方法：

1. 将 `Get-ExchangeDBStatus.ps1` 加入计划任务，每分钟执行一次
2. 修改 Exchange 服务器的 `Zabbix Agent` 服务配置，可以参考 `zabbix_agentd.conf`
3. Zabbix 中导入模版 `ZabbixTemplate_Exchange Server 2016 Database Monitor.xml`
4. 将源码中的另外两个脚本 `Get-ExchangeDBDiscovery.ps1`、`Get-ExchangeDB.ps1` 放到与 `zabbix_agentd.conf` 同级或自定义目录中（放置在自定义目录需要修改 `zabbix_agentd.conf` 中的脚本路径）

如果是较大型的企业或数据库服务器较多，推荐将三个 powershell 脚本置于 UNC 路径中，Zabbix 是支持的，这样便于部署配置。

## 后记

其实在早期曾经尝试过在一台机器上进行所有数据库的收集，这样会让整个方案建立起来快速和方便得多，只需要执行一次脚本，也不需要那么多的判断。但是对于 50 个以上数据库规模的架构，这个方法不适用了，一方面脚本执行效率堪忧，完整执行一次可能要 5 分钟以上，这对于我们 99.995% 的 SLA 要求显然是不能够满足需求的；其次 Zabbix 对于单个主机的监控项收集效率也不够，实测起来可能会产生最多 15 分钟的延迟告警，这样是无法接受的。

如果是小型公司，数据库数量使用单一脚本做全部数据库收集显然是没问题的
