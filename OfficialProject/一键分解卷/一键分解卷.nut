function _Dps_OneClickDisassemblyOfRoll_Logic_() {
    local Config = GlobalConfig.Get("一键分解卷_Lenheart.json");
    //分解券
    Cb_Use_Item_Sp_Func[Config["分解卷的道具ID"]] <- function(SUser, ItemId) {
	    local index = 0;
	    local InvenObj = SUser.GetInven();
	    if (InvenObj) {
	    	for (local i = Config["一键分解的起始位置_就是背包从第几格开始"]; i <= Config["一键分解的结束位置_就是背包到第几格结束"]; i++) { // 遍历9到16号背包格子
	    		local ItemObj = InvenObj.GetSlot(1, i);
	    		if (!ItemObj.IsEmpty) {
	    			local item_id = ItemObj.GetIndex(); // 获取物品ID
	    			local PvfItemObj = PvfItem.GetPvfItemById(item_id);
	    			local CItem_get_rarity = PvfItemObj.GetRarity(); // 装备品级
	    			local item_upgrade = ItemObj.GetUpgrade();
	    			local item_name = PvfItem.GetNameById(item_id);
	    			if (CItem_get_rarity <= Config["分解品级(含)"]) { // 粉装及以下品级装备

	    				// 检查副职业是否开启
	    				local checkTag = Sq_CallFunc(S_Ptr("0x822f8d4"), "int", ["pointer"], SUser.C_Object);
	    				local is = SUser.GetCurCharacExpertJob();
	    				if (!is) {
	    					// 如果副职业未开启则调用诺顿分解机
	    					SUser.DisPatcher_DisJointItem_disjoint(i, 28, S_Ptr("0x0"));
	    				} else {
	    					// 如果副职业已开启则调用自身分解机
	    					SUser.DisPatcher_DisJointItem_disjoint(i, 239, SUser.C_Object);
	    				}
	    				if (item_upgrade > 0) {
	    					item_name = "+" + item_upgrade + item_name;
	    				}
	    				local newItemObj = InvenObj.GetSlot(1, i);
	    				if (newItemObj.IsEmpty) { // 如果分解成功
	    					index++;
	    					SUser.SendUpdateItemList(1, 0, i);
	    					local AdMsgObj = AdMsg();
                            AdMsgObj.PutType(Config["分解成功提示发送位置"]);
                            if (Config["分解成功提示发送位置"] != 14) {
                                AdMsgObj.PutString(" ");
                            }
	    					AdMsgObj.PutString(" 成功分解装备");
	    					AdMsgObj.PutEquipment("[" + item_name + "]", ItemObj, DisJointItemBynangua.RarityColor(item_id));
	    					AdMsgObj.Finalize();
	    					SUser.Send(AdMsgObj.MakePack());
	    					AdMsgObj.Delete();
	    				}
	    			}
	    		}
	    	}

	    	if (index > 0) {
	    		SUser.SendNotiPacketMessage("恭喜: " + index + " 件装备分解成功。", 8);
	    	} else {
	    		SUser.SendNotiPacketMessage("装备分解失败，道具已返还", 8);
	    	}
            if (Config["是否返还分解券道具(true代表返还,false代表不返还)"]) {
				Timer.SetTimeOut(function() {
                    SUser.GiveItem(ItemId, 1);
                }, 1);
            }
	    }
    };
}

class DisJointItemBynangua {
	function RarityColor(item_id) {
		local PvfItemObj = PvfItem.GetPvfItemById(item_id);
		if (PvfItemObj == null) {
			return;
		}
		local CItem_get_rarity = PvfItemObj.GetRarity(); // 装备品级
		return DisJointItemBynangua.rarityColorMap[(CItem_get_rarity).tostring()];
	}
    rarityColorMap = {
		"0": [255, 255, 255], // 普通
		"1": [104, 213, 237], // 高级
		"2": [179, 107, 255], // 稀有
		"3": [255, 0, 255], // 神器
		"4": [255, 180, 0], // 史诗
		"5": [255, 102, 102], // 勇者
		"6": [255, 20, 147], // 深粉红色
		"7": [255, 215, 0] // 金色
	};
}

function _Dps_OneClickDisassemblyOfRoll_Main_() {
    _Dps_OneClickDisassemblyOfRoll_Logic_();
}

function _Dps_OneClickDisassemblyOfRoll_Main_Reload_(OldConfig) {
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["分解卷的道具ID"]);
    _Dps_OneClickDisassemblyOfRoll_Logic_();
}