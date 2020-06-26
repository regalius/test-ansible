#!/bin/bash
MEM_SOFT_LIMIT_PERCENT=80
MEM_HARD_LIMIT_PERCENT=80
CPU_SOFT_LIMIT_PERCENT=80
CPU_HARD_LIMIT_PERCENT=80

# /proc/meminfo output is in kb, convert to bytes first
MEM_SOFT_LIMIT=$(($(awk '/^MemTotal:/{print $2}' /proc/meminfo)*1000*MEM_SOFT_LIMIT_PERCENT/100 ))
MEM_HARD_LIMIT=$(($(awk '/^MemTotal:/{print $2}' /proc/meminfo)*1000*MEM_HARD_LIMIT_PERCENT/100 ))

# 1024 is max cpu share
CPU_SOFT_LIMIT=$((1024 * $CPU_SOFT_LIMIT_PERCENT/100))

# Set CPU throttle and eval time to 1s
CPU_CFS_QUOTA=100000

# Set CPU quota / eval time as percentage of eval time * num of processor
NUM_OF_PROCESSOR=$(nproc)
CPU_CFS_PERIOD=$((CPU_HARD_LIMIT_PERCENT/100 * NUM_OF_PROCESSOR * CPU_CFS_QUOTA))

# create cgroup given mem and cpu limit above
cgcreate -g cpu,memory:tkpdlimit
# Soft limit for memory
cgset -r memory.soft_limit_in_bytes=$MEM_SOFT_LIMIT tkpdlimit

# Hard limit for memory
cgset -r memory.limit_in_bytes=$MEM_HARD_LIMIT tkpdlimit

# Soft limit for CPU
cgset -r cpu.shares=$CPU_SOFT_LIMIT tkpdlimit

# Hard limit for CPU
cgset -r cpu.cfs_quota_us=$CPU_CFS_QUOTA tkpdlimit
cgset -r cpu.cfs_period_us=$CPU_CFS_PERIOD tkpdlimit

# Run cgrulesengd deamon
cgrulesengd