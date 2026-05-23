// 在线奖励活动入口点
function _Dps_TimeReward_Main_() {
    _Dps_TimeReward_Logic_();
}

// 格式化时间字符串
function normalize_time_format(time_str) {
    local colonPos = time_str.find(":");
    if (colonPos == null) return null;
    
    local hour = time_str.slice(0, colonPos).tointeger();
    local minute = time_str.slice(colonPos + 1).tointeger();
    
    return format("%02d:%02d", hour, minute);
}

// 在线奖励活动重载入口点
function _Dps_TimeReward_Main_Reload_(OldConfig) {
    // 移除旧配置中的所有定时任务
    if (OldConfig && "奖励时间和内容" in OldConfig) {
        foreach(time, reward in OldConfig["奖励时间和内容"]) {
            local task_id = "TimeRewardTask_" + normalize_time_format(time);
            Timer.RemoveCronTask(task_id);
        }
    }

    // 重新注册
    _Dps_TimeReward_Logic_();
}

// 在线奖励活动逻辑入口点
function _Dps_TimeReward_Logic_() {
    local Config = GlobalConfig.Get("整点在线奖励_Lenheart.json");

    if(!Config["是否启用在线奖励(true启用/false不启用)"]) {
        return;
    }

    // 遍历配置的所有奖励时间
    foreach(time, reward in Config["奖励时间和内容"]) {
        local hour = time.slice(0, time.find(":")).tointeger();
        local minute = time.slice(time.find(":") + 1).tointeger();

        // 为每个时间点创建独立的回调函数
        local callback = function(originalTime = time) {
            SendTimeReward(originalTime);
        }

        // 为每个时间点注册一个定时任务
        local cronExpression = format("0 %d %d * * *", minute, hour);
        Timer.SetCronTask(callback, {
            Cron = cronExpression,
            Name = "TimeRewardTask_" + normalize_time_format(time)
        });
    }
}

// 发放在线奖励
function SendTimeReward(rewardTime) {
    local Config = GlobalConfig.Get("整点在线奖励_Lenheart.json");
    local OnlinePlayerList = World.GetOnlinePlayer();
    
    // 直接使用原始时间格式查找奖励
    local reward = Config["奖励时间和内容"][rewardTime];
    if (!reward) return;

    // 发放奖励
    foreach(SUser in OnlinePlayerList) {
        // 检查是否为假人
        local IP = _Dps_TimeReward_api.api_CUser_get_public_ip_address(SUser);
        if (!Config["是否发放奖励给假人(true发放/false不发放)"] && IP == Config["离线假人IP"]) {
            continue;
        }

        // 准备邮件奖励物品列表
        local RewardItems = [];
        foreach(itemR in reward) {
            RewardItems.append([itemR[0], itemR[1]]);
        }

        // 发送邮件（显示时使用规范化的时间格式）
        local title = Config["邮件标题"];
        local Text = format(Config["邮件内容"], normalize_time_format(rewardTime));
        SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems);
    }

    // 发送全服公告（显示时使用规范化的时间格式）
    World.SendNotiPacketMessage(format(Config["公告"], normalize_time_format(rewardTime)), 14);
}

// API类
class _Dps_TimeReward_api {
    // 获取玩家IP地址
	function api_CUser_get_public_ip_address(SUser){
		local s_addr = Sq_CallFunc(S_Ptr("0x084EC90A"), "int", ["pointer"], SUser.C_Object);
		if(s_addr){
		    local inet_ntoa = Sq_CallFunc(S_Ptr("0x0807DDC0"), "pointer", ["int"], s_addr);
		    return NativePointer(inet_ntoa).readUtf8String();
		}
		return null;
	}
}

