_total_rewardBynangua <- {}; // 存储每个玩家的累计奖励

function _Online_rewardsBynangua() {
    local Config = GlobalConfig.Get("在线泡点配置_Nangua.json");
    local OnlinePlayerList = World.GetOnlinePlayer();

    // 发放奖励
    foreach(SUser in OnlinePlayerList) {
        local IP = _Online_rewardsBynangua_api.CUser_get_public_ip_address(SUser);
        if (!Config["是否发放奖励给假人(true发放/false不发放)"] && IP == Config["离线假人IP"]) {
            continue;
        }

        // 获取奖励类型和数量
        local isCera = Config["在线泡点配置"]["奖励类型(true点券/false代币)"];
        local rewardAmount = isCera ? Config["在线泡点配置"]["点券奖励"] : Config["在线泡点配置"]["代币奖励"];

        if (rewardAmount > 0) {
            // 初始化累计奖励
            if (!(SUser.GetCID() in _total_rewardBynangua)) {
                _total_rewardBynangua[SUser.GetCID()] <- 0;
            }
            _total_rewardBynangua[SUser.GetCID()] += rewardAmount;

            // 发放奖励
            if (isCera) {
                SUser.RechargeCera(rewardAmount);
            } else {
                SUser.RechargeCeraPoint(rewardAmount);
            }

            // 发送消息
            local AdMsgObj = AdMsg();
            AdMsgObj.PutType(Config["在线泡点配置"]["信息发送位置"]);
            if (Config["在线泡点配置"]["信息发送位置"] != 14) {
                AdMsgObj.PutString(" ");
            }
            AdMsgObj.PutImoticon(Config["在线泡点配置"]["图标"]);
            AdMsgObj.PutColorString(Config["在线泡点配置"]["标题"], Config["在线泡点配置"]["文字颜色rgb"]);
            AdMsgObj.PutColorString("[" + rewardAmount + "]", Config["在线泡点配置"]["数量颜色rgb"]);
            AdMsgObj.PutColorString(Config["在线泡点配置"]["奖励内容(代币/点券)"], Config["在线泡点配置"]["文字颜色rgb"]);
            AdMsgObj.PutColorString(Config["在线泡点配置"]["奖励"], Config["在线泡点配置"]["文字颜色rgb"]);
            AdMsgObj.PutColorString("[" + _total_rewardBynangua[SUser.GetCID()] + "]", Config["在线泡点配置"]["数量颜色rgb"]);
            AdMsgObj.PutColorString(Config["在线泡点配置"]["奖励内容(代币/点券)"], Config["在线泡点配置"]["文字颜色rgb"]);
            AdMsgObj.Finalize();
            SUser.Send(AdMsgObj.MakePack());
            AdMsgObj.Delete();
        }
    }
}

// 在线泡点活动入口点
function _Dps_Online_rewardsBynangua_Main_() {
    _Dps_Online_rewardsBynangua_Logic_();
}

// 在线泡点活动重载入口点
function _Dps_Online_rewardsBynangua_Main_Reload_(OldConfig) {
    // 先移除旧的定时任务
    Timer.RemoveCronTask("OnlineRewardTask");

    // 重新注册
    _Dps_Online_rewardsBynangua_Logic_();
    // 清理缓存
    _total_rewardBynangua <- {};
}

// 在线泡点活动逻辑入口点
function _Dps_Online_rewardsBynangua_Logic_() {
    local Config = GlobalConfig.Get("在线泡点配置_Nangua.json");
    local interval = Config["在线泡点配置"]["时间间隔(分钟)"];
    local cronExpression = format("0 */%d * * * *", interval);
    // 注册定时任务
    Timer.SetCronTask(_Online_rewardsBynangua, {
        Cron = cronExpression,
        Name = "OnlineRewardTask"
    });
}

class _Online_rewardsBynangua_api {
	function CUser_get_public_ip_address(SUser){
		local s_addr = Sq_CallFunc(S_Ptr("0x084EC90A"), "int", ["pointer"], SUser.C_Object);
		if(s_addr){
		    local inet_ntoa = Sq_CallFunc(S_Ptr("0x0807DDC0"), "pointer", ["int"], s_addr);
		    return NativePointer(inet_ntoa).readUtf8String();
		}
		return null;
	}
}

// 玩家下线时，清空累计奖励
Cb_CUser_LogoutToPCRoom_Enter_Func.Online_rewardsBynangua <-  function(args) {
    local SUser = User(args[0]);
    if (SUser.GetCID() in _total_rewardBynangua) {
        _total_rewardBynangua.rawdelete(SUser.GetCID());
    }
}
