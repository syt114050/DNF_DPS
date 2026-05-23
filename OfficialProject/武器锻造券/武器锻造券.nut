function WeaponForgingBynangua(SUser, ItemId) {
	local Config = GlobalConfig.Get("武器锻造券配置_Nangua.json");
	local ItemIdStr = ItemId.tostring();

	if (Config["武器锻造券配置"].rawin(ItemIdStr)) {
		local forgingConfig = Config["武器锻造券配置"][ItemIdStr];
		local Level = forgingConfig["锻造等级"];
		local SuccessRate = forgingConfig["成功率"];

		// 获取玩家背包
		local InvenObj = SUser.GetInven();
		if (!InvenObj) return;

		// 获取玩家背包类型1的第9个格子
		local ItemObj = InvenObj.GetSlot(1, 9);

		// 判断装备是否存在
		if (ItemObj.IsEmpty) {
			_UpdateWeaponNotify.NotifyUserAndReturn(SUser, ItemId, Config["提示信息"]["装备不存在"]);
			return;
		}

		// 获取装备类型
		local ItemInfo = PvfItem.GetPvfItemById(ItemObj.GetIndex());
		local ItemType = NativePointer(ItemInfo.C_Object).add(141 * 4).readU32();
		if (ItemType != 10) {
			_UpdateWeaponNotify.NotifyUserAndReturn(SUser, ItemId, Config["提示信息"]["非武器装备"]);
			return;
		}

		// 获取原装备的锻造等级
		local OldLevel = ItemObj.GetForging();
		if (OldLevel >= Level) {
			_UpdateWeaponNotify.NotifyUserAndReturn(SUser, ItemId, Config["提示信息"]["锻造等级已达到"]);
			return;
		}

		// 随机数生成
		local RandNum = MathClass.Rand(0, 101);
		if (RandNum <= SuccessRate) {
			// 设置装备的锻造等级
			ItemObj.SetForging(Level);
			ItemObj.Flush();
			SUser.SendUpdateItemList(1, 0, 9);

			// 根据配置选择发送消息的方式
			if (Config["启用233发包(true/false)"]) {
				SUser.SendNotiBox(format(Config["提示信息"]["锻造成功"], Level), 1);
			} else {
				SUser.SendNotiPacketMessage(format(Config["提示信息"]["锻造成功"], Level), 8);
			}
		} else {
			// 根据配置选择发送消息的方式
			if (Config["启用233发包(true/false)"]) {
				SUser.SendNotiBox(Config["提示信息"]["锻造失败"], 1);
			} else {
				SUser.SendNotiPacketMessage(Config["提示信息"]["锻造失败"], 8);
			}
		}
	}
}
class _UpdateWeaponNotify {
    function NotifyUserAndReturn(SUser, ItemId, message) {
    	local Config = GlobalConfig.Get("武器锻造券配置_Nangua.json");

    	// 根据配置选择发送消息的方式
    	if (Config["启用233发包(true/false)"]) {
    		SUser.SendNotiBox(message, 1);
    	} else {
    		SUser.SendNotiPacketMessage(message, 8);
    	}

    	SUser.GiveItem(ItemId, 1);
    }
}

//加载入口
function _Dps_UpdateWeaponSeparate_Main_() {
	_Dps_WeaponForging_Logic_();
}

//重载入口
function _Dps_WeaponForging_Main_Reload_(OldConfig) {
	local Config = GlobalConfig.Get("武器锻造券配置_Nangua.json");
	// 删除旧的注册
	foreach(itemId, _ in OldConfig["武器锻造券配置"]) {
		Cb_Use_Item_Sp_Func.rawdelete(itemId.tointeger());
	}
	//重新注册
	_Dps_WeaponForging_Logic_();
}

function _Dps_WeaponForging_Logic_() {
	local Config = GlobalConfig.Get("武器锻造券配置_Nangua.json");
	// 注册所有武器锻造券
	foreach(itemId, _ in Config["武器锻造券配置"]) {
		Cb_Use_Item_Sp_Func[itemId.tointeger()] <- WeaponForgingBynangua;
	}
}