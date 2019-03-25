---
title: F5 可用性研究以及使用 Zabbix 监控 F5 
date: 2019-03-24 17:56:33
categories: [Moniting, F5]
toc: true
thumbnail: https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/4yi7i.jpg
---
[博客原文](https://archeanz.com/2019/03/24/Moniting-F5-with-Zabbix/)
目前部门的各类系统大部分都使用 F5 发布 VIP 提供给用户使用，而之前对 F5 的监控基本没有，本文诣在研究如何通过 SNMP 的方式读取 F5 的各类状态、性能指标，以及什么样的状况需要去告警。
<!--more-->
将 F5 的 OID 模版导入到 Zabbix Server 的 `/usr/share/snmp/mibs` 目录中之后，即可使用 `snmpwalk` 命令请求 F5 的各项状态。在请求时，大部分值均需要增加 OID 前缀，本文基本只涉及 `F5-BIGIP-LOCAL-MIB.txt` 这个模版中的内容，所以请求命令的样子如下：

```
snmpwalk -v2c -c public F5.hostname.or.IP F5-BIGIP-LOCAL-MIB::ltmPoolMemberMonitorStatus
```
## F5 Status
F5 自身状态中需要关注的一个是 CPU、内存使用率，另外就是主备同步状态及故障转移状态。
### Failover Status
待补充
### ConfigSync Status
待补充
## Virtual Server

Virtual Server（VS）是 F5 对外提供访问的入口，是 Local Traffic Manager（LTM）中最外层的对象，一旦 Down 掉了整体服务将不可用。这也是除 F5 本身挂掉以外最严重的问题。

### VS Status

VS 状态对应的一个 OID 值是 `ltmVsStatusAvailState`，这代表了 VS 可用状态。除此之外，还需要关注 VS 的运营状态，其 OID 值是 `ltmVsStatusEnabledState`。

| ICON | 可用状态    | 运营状态 | 可用状态代码   |运营状态代码   | 描述 |
|:--------:|-----------|----------|------------|--------------|---------------|
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/35fu3.png) | Avaliable | Enabled  | GREEN（0） | ENABLED(1)| VS 已启用且池成员健康检查正常 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/jxv98.png) | Unknown   | Enabled  | BLUE（4） | ENABLED(1) | VS 已启用但没有成员|
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/y50yv.png) | Offline | Enabled | RED（3）| ENABLED(1) |  VS 已启用但池成员健康检查异常 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/i5ugu.png) | Avaliable | Disabled | GREEN（0）| DISABLED(2) |  VS 已禁用且池成员健康检查正常 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/dc7m3.png) | Unknown | Disabled | BLUE（4）| DISABLED(2) |  VS 已禁用但没有成员 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/x46rg.png) | Offline |  Disabled | RED（3）| DISABLED(2) |  VS 已禁用且池成员健康检查异常 |

`RED(3) `状态应该是我们最需要关注的状况。如果运营状态为 `Enabled` 且可用状态是 `Offline`，即代表此 VS 出现了不可用的状况。

### VS Statistics

VS Statistics 中比较需要关注的包括流量、连接数、请求次数。分别对应下面几个 OID 值：
* ltmVirtualServStatClientCurConns
* ltmVirtualServStatTotRequests
* ltmVirtualServStatClientBytesOut
* ltmVirtualServStatClientBytesIn

## Pool

Pool 是 VS 的资源池，通过某种负载均衡方式将请求转发至池中的 Member。

### Pool Status

资源池也是有状态的，但只有可用状态，无运营状态。相应的，其 OID 值是 `ltmPoolStatusAvailState`，池的状态同样列举如下：

| ICON | 可用状态    |  可用状态代码   | 描述 |
|:--------:|-----------|------------|-----------------------------|
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/35fu3.png) | Avaliable | GREEN（0） | 池成员健康检查正常 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/jxv98.png) | Unknown | BLUE（4） | 池成员健康检查状态未知 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/y50yv.png) | Offline | RED（3） |  池成员健康检查异常 |

关注资源池的状态意义不太明显，因为就目前的服务发布架构（一个 VS 对应一个 Pool），池状态变为 Offline 时，VS 一定也会变成 Offline。所以基本上只需要关注 Pool 的统计数字即可。

### Pool Statistics

Pool Statistics 中的统计数字可以为整体运营数据提供另一个纬度的指标，意义不如 VS Statistics 那样明显，对应的 OID 值如下：
* ltmPoolLbMode
* ltmPoolStatusAvailState 
* ltmPoolActiveMemberCnt
* ltmPoolStatServerCurConns
* ltmPoolStatTotRequests
* ltmPoolStatServerBytesOut
* ltmPoolStatServerBytesIn

## Node
Node 是 LTM 中最小的粒度，对应的是实际的服务器（Real Server or RS），Node 是 Pool 中的成员，

### Node Status
这里讨论的 Node 的状态只包括运营状态 `ltmNodeAddrStatusEnabledState`，因为在现存架构中，Node 的可用状态必须结合 Pool 的健康检查方式来看。Node 可用状态也可以单独设定，但不在本文的讨论范围内。

| ICON | 运营状态    |  运营状态代码   | 描述 |
|:--------:|-----------|------------|-----------------------------|
| 黑色 | Disabled | disabled(1) | 已禁用 |
| 其他 | Enabled | enabled(0) | 已启用 |

### Node Statistics
Node 的统计数字仅仅作为单机流量的参考，主要包括下面几个 OID 值：
* ltmNodeAddrStatServerBytesIn
* ltmNodeAddrStatServerBytesOut
* ltmNodeAddrStatServerCurConns

## Pool Member Monitor Status
其实相比 Pool Status，更有用的应该是 Pool Member Monitor Status，由于所有的业务均由 F5 统一发布，所以 F5 有着最为敏锐、实时的健康检查机制：一旦发布的服务端口不可用，或延迟较高，则马上将其在 Pool 中排除，以免将用户请求分发到问题节点，从而引起访问超时甚至不可用。

于是，监控 F5 的健康检查状态，比直接使用 Zabbix 的端口检测更加直接。但是，由于 F5 自己会排除问题节点，所以单纯的节点故障不会引起整个服务的异常。此监控产生的告警仅仅需要知会管理员，按照我的监控定义，生成二级告警即可。

| ICON | 可用状态    |  可用状态代码   | 描述 |
|:--------:|-----------|------------|-----------------------------|
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/35fu3.png) | Availabe | up(4) | 可用 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/y50yv.png) | Offline | down (19) | 不可用 |
| ![](https://archean-1256172257.cos.ap-beijing.myqcloud.com/blog/x46rg.png) | Forced Down | forcedDown (20) | 已禁用且不可用 |

### Pool Active Member Percentage
目前的服务发布机制，每个 Pool 中的服务器数量均基本大于 3 个，相比单纯的 Member Status，关注 Pool 中活动节点的比例显得更为重要。

服务架构设计之初，即考虑到了其冗余性，极端状况下，允许一半的节点停止服务，于是

Active Member Percentage 可以通过活动节点数量 `ltmPoolActiveMemberCnt` 除以全部节点数量 `ltmPoolMemberCnt` 来计算出来。

## Alarm Policy
根据上述内容，我制定出 F5 监控的告警策略，分为一、二、三级告警，分别对应 High、Average、Warning 三个内置告警级别：

### High
* VS Offline
* Pool Active Member Percentage < 50%
* CPU Usage > 80%

### Average
* Pool Member Monitor Status Offline
* Failover Status Failed
* Pool Offline

### Warning
* Pool Member Monitor Status Disabled
* ConfigSync Status NotSync
* Node Disabled
* VS Disabled


