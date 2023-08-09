#!/bin/sh
# 添加和删除IPTV路由表项，使得所有设备均能访问IPTV网络183.59.0.0/16
if [ "$1" != "-n" ] && [ "$1" != "-d" ];then
  # 使用ping命令检测网络连接
  ping -c 1 -W 1 183.59.168.27 > /dev/null 2>&1
  # 如果返回值为0，表示网络正常，就退出脚本
  if [ $? -eq 0 ]; then
    echo "网络正常，退出脚本"
    exit 0
  fi
fi
if [ -f /tmp/routeadd.sh ]; then
  echo "删除之前的路由表项"
  /bin/ash /tmp/routeadd.sh 2>/dev/null
  rm -f /tmp/routeadd.sh
  if [ "$1" == "-d" ]; then exit 0; fi
fi
echo "正在查找ppp接口..."
# 定义一个计数器
count=0
# 定义一个循环
while true; do
  # 每隔3秒查找名称为ppp开头的接口名称
  # 如果循环次数超过30次就退出
  if [ $count -gt 30 ]; then
    echo "找不到两个ppp接口，退出脚本"
    exit 1
  fi
  # 获取ifconfig的所有输出，避免重复执行ifconfig
  ifconfig_output=$(ifconfig)
  # 查找名称为ppp开头的接口名称
  ppp_list=$(echo "$ifconfig_output" | grep -o "^ppp[0-9]\+")
  # 计算接口数量
  ppp_count=$(echo "$ppp_list" | wc -l)
  # 如果接口数量不等于2，持续循环
  if [ $ppp_count -ne 2 ]; then
    # 如果没有找到两个ppp接口，增加计数器并等待3秒再循环
    count=$((count+1))
    sleep 3
  else
    echo "找到了2个ppp接口，开始执行操作"
    break
  fi
done

# 获取两个ppp接口的接口名称，"inet addr"对应的地址，"P-to-P"对应的地址
for ppp in $ppp_list; do
  # 获取接口名称
  ppp_name=$ppp
  # 获取"inet addr"对应的地址
  ppp_inet=$(echo "$ifconfig_output" | grep -A1 "$ppp_name" | grep "inet addr" | awk '{print $2}' | cut -d: -f2)
  # 获取"P-to-P"对应的地址
  ppp_ptop=$(echo "$ifconfig_output" | grep -A1 "$ppp_name" | grep "P-t-P" | awk '{print $3}' | cut -d: -f2)
  # 判断ip地址是否为10.开头的
  if echo "$ppp_inet" | grep -q "^10\."; then
    # 如果是，保存该接口名称和"P-to-P"对应的地址
    ppp_10_name=$ppp_name
    ppp_10_ptop=$ppp_ptop
  else
    # 如果不是，保存该接口的"inet addr"对应的地址
    ppp_other_inet=$ppp_inet
  fi
done
# 通过ip rule list 查询ip地址为$ppp_other_inet的table编号
table_num=$(ip rule list | grep "$ppp_other_inet" | awk '{print $5}')
# 如果找不到table编号，退出脚本
if [ -z "$table_num" ]; then
  echo "找不到ip地址为$ppp_other_inet的table编号，退出脚本"
  exit 2
fi
# 执行命令ip route add 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table $table_num和ip route add 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table main
echo "ip route del 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table $table_num" > /tmp/routeadd.sh
echo "ip route del 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table main" >> /tmp/routeadd.sh
ip route add 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table $table_num && echo "添加路由到table $table_num成功" || echo "添加路由到table $table_num失败"
ip route add 183.59.0.0/16 via $ppp_10_ptop dev $ppp_10_name table main && echo "添加路由到table main成功" || echo "添加路由到table main失败"
