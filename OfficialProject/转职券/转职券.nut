
// =================== 加载 JSON 配置 =================== 
local rawConfig = GlobalConfig.Get("转职券.json");
local CLASS_CHANGE_ITEMS = {};

// 转换字符串键到整型键
foreach(keyStr, config in rawConfig.class_change_items) {
    try {
        CLASS_CHANGE_ITEMS[keyStr.tointeger()] <- config;
    } catch(e) {
        ::print("[ERROR] 转换道具ID失败: " + keyStr + "\n");
    }
}

// =================== 通用转职函数 ===================
function ChangeGrowTypeHandler(SUser, ItemId) {
	// 读取角色信息
	local curJob = SUser.GetCharacJob();
	local curGrow = SUser.GetCharacGrowType();
	local curLevel = SUser.GetCharacLevel();
	local curAwaken = SUser.GetCharacSecondGrowType();

	// 获取转职配置
	local config = CLASS_CHANGE_ITEMS[ItemId];

	// 条件验证
	if (curLevel < 20) return SendClassChangeError(SUser, "角色等级不足20级！", ItemId);

	if (curJob != config.job) return SendClassChangeError(SUser, "职业不符无法使用！", ItemId);

	if (curAwaken > 0) return SendClassChangeError(SUser, "觉醒后无法转职！", ItemId);

	if (curGrow == config.grow) return SendClassChangeError(SUser, "已处于目标职业分支！", ItemId);

	// 执行转职操作
	SUser.ChangeGrowType(config.grow, 0);
	SUser.InitSkillW(1, 0);
	SUser.SendNotiPacket(0, 2, 0);
	SUser.SendNotiPacketMessage("角色转职成功！", 0);
}

// =================== 错误处理函数 ===================
function SendClassChangeError(SUser, msg, itemId) {
	SUser.SendNotiPacketMessage(msg, 0);
	SUser.SendNotiBox(msg, 1);
	SUser.GiveItem(itemId, 1); // 退还道具
}

//加载入口
function _Dps_CLASS_CHANGE_Main_() {
    if ("class_change_items" in rawConfig) {
        foreach (itemId, _ in CLASS_CHANGE_ITEMS) {
            Cb_Use_Item_Sp_Func[itemId] <- ChangeGrowTypeHandler;
        }
        ::print("[SUCCESS] 注册转职道具数量: " + CLASS_CHANGE_ITEMS.len() + "\n");
    } else {
        ::print("[ERROR] 转职配置缺失 class_change_items 节点\n");
    }
}