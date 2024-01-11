#!/bin/bash

# 定义 miner 变量
miner=$1 # 请替换为您的矿工 ID
ip=$2    # 请替换为您的工作节点 IP

echo $(date)
echo "miner:$miner"
echo "rebuild-worker-ip:$ip"

# 1. 查找所有错误的 sector
sectors=$(/root/damocles-manager util sealer proving --miner $miner faults | grep -v Miner | grep -v deadline | awk '{print $3}')

if [ -z "$sectors" ]; then
  echo "未发现错误 sector。结束本次任务。"
  exit 0
fi

echo "发现错误 sectors: $sectors"

# 遍历每个错误的 sector
for sectorid in $sectors; do
  echo "处理 Sector $sectorid ..."

  # 2. 检查该 sector 是否正在被重建
  isRebuilding=$(/root/damocles-manager util sealer sectors state $miner $sectorid | grep -i rebuild | awk '{print $2}')

  if [ "$isRebuilding" == "true" ]; then
    echo "Sector $sectorid 正在被重建。"

    # 4. 如果正在被重建，查看重建状态，是否有错误
    res=$(/root/damocles-manager util worker info $ip | grep $sectorid | grep permanent)
    if [ ! -z "$res" ]; then
      echo "检测到重建错误。"

      # 5. 处理错误
      index=$(echo $res | awk '{print $1}')
      file=$(echo $res | awk '{print $4}')
      mv /mnt/hass_hk21-26/sealed/$file /mnt/hass_hk21-26/sealed/${file}-fault
      mv /mnt/hass_hk21-26/cache/$file /mnt/hass_hk21-26/cache/${file}-fault

      # 等待hass mv 完成
      sleep 10

      # 6. 完成后执行 resume
      /root/damocles-manager util worker resume $ip $index
    else
      echo "重建过程中未检测到错误。"
    fi
  else
    echo "Sector $sectorid 没有被重建。"

    # 3. 如果没有被重建，手动进行重建
    /root/damocles-manager util sealer sectors rebuild $miner $sectorid
  fi
done

# 7. 结束本次任务
echo "所有错误 sectors 的处理完成。"
