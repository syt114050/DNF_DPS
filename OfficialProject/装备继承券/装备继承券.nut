
function InheritFuncBynangua(SUser, ItemId) {
    local Config = GlobalConfig.Get("装备继承券配置_Nangua.json");
    //获取玩家背包
    local InvenObj = SUser.GetInven();
    if(!InvenObj) {
        return;
    }
    //获取装备栏第一栏装备
    local firstItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_ITEM, Config["继承配置"]["装备1摆放位置"]);
    //获取装备栏第二栏装备
    local secondItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_ITEM, Config["继承配置"]["装备2摆放位置"]);
    //装备不存在
    if (firstItemObj.IsEmpty || secondItemObj.IsEmpty) {
        _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示1"]);
        return;
    }
    //获取ID
    local firstItemIndex = firstItemObj.GetIndex();
    local secondItemIndex = secondItemObj.GetIndex();
    //获取类型
    local firstItemInfo = PvfItem.GetPvfItemById(firstItemIndex);
    local firstItemType = NativePointer(firstItemInfo.C_Object).add(141 * 4).readU32();
    local secondItemInfo = PvfItem.GetPvfItemById(secondItemIndex);
    local secondItemType = NativePointer(secondItemInfo.C_Object).add(141 * 4).readU32();
    //判断是否在禁止继承装备中
    foreach(exceptItemIndex in Config["继承配置"]["禁止继承装备ID"]) {
        if(firstItemIndex == exceptItemIndex || secondItemIndex == exceptItemIndex) {
            //获取装备名字
            local ItemName = PvfItem.GetNameById(exceptItemIndex);
            _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, format(Config["继承配置"]["继承失败提示5"], ItemName));
            return;
        }
    }
    // 禁止继承的装备类型(10武器，11称号，12上衣，13头肩，14下装，15鞋子，16腰带，17项链，18手镯，19戒指，20左槽，21右槽)
    if (Config["继承配置"]["禁止继承装备类型"].find(firstItemType || secondItemType) != null) {
        _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示2"]);
        return;
    }
    // 1、2栏装备类型不同无法继承
    if (firstItemType != secondItemType) {
        _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示2"]);
        return;
    }
    //装备等级大于等于50级才可以继承，1、2栏装备等级差距超过5级无法继承
    if (firstItemInfo.GetUsableLevel() < Config["继承配置"]["装备等级大于等于多少允许继承"] || secondItemInfo.GetUsableLevel() < Config["继承配置"]["装备等级大于等于多少允许继承"] || _InheritBynangua.CheckUsableLevelBynangua(firstItemInfo.GetUsableLevel() - secondItemInfo.GetUsableLevel()) > Config["继承配置"]["装备等级跨度超过多少不允许继承"]) {
        _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示3"]);
        return;
    }
    //装备品级低于3无法继承
    if (firstItemInfo.GetRarity() < Config["继承配置"]["装备品级低于多少不允许继承"] || secondItemInfo.GetRarity() < Config["继承配置"]["装备品级低于多少不允许继承"]) {
        _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示4"]);
        return;
    }
    if (!Config["继承配置"]["是否允许不同品级的装备继承(true可以,false不可以)"]) {
        if (firstItemInfo.GetRarity() != secondItemInfo.GetRarity()) {
            _InheritBynangua.NotifyUserAndReturn(SUser, ItemId, Config["继承配置"]["继承失败提示4"]);
            return;
        }
    }
    //满足以上条件后开始执行继承逻辑
    //将第一个装备的属性继承到第二个装备
    Sq_CallFunc(S_Ptr("0x8671EB2"), "int", ["pointer", "pointer", "pointer"], SUser.C_Object, secondItemObj.C_Object, firstItemObj.C_Object);
    // 将第一个装备的镶嵌数据库ID设置为0
    NativePointer(firstItemObj.C_Object).add(25).writeU32(0);
    //获取异界气息属性
    local firstBreath = NativePointer(firstItemObj.C_Object).add(31).readU8();
    local secondBreath = NativePointer(firstItemObj.C_Object).add(32).readU8();
    if(firstBreath > 0 && Config["继承配置"]["是否允许继承异界气息(true可以,false不可以)"]) {
        //写入异界气息属性
        NativePointer(secondItemObj.C_Object).add(31).writeU8(firstBreath);
        NativePointer(secondItemObj.C_Object).add(32).writeU8(secondBreath);
        //清除第一件装备异界气息属性
        NativePointer(firstItemObj.C_Object).add(31).writeU8(0);
        NativePointer(firstItemObj.C_Object).add(32).writeU8(0);
    }
    //移除被继承装备属性
    local removeAttributes = [6, 17, 51, 13];
    foreach (attributes in removeAttributes) {
        NativePointer(firstItemObj.C_Object).add(attributes).writeU8(0);
    }
    //刷新背包信息
    SUser.SendUpdateItemList(1, 0, Config["继承配置"]["装备1摆放位置"]);
    SUser.SendUpdateItemList(1, 0, Config["继承配置"]["装备2摆放位置"]);
    firstItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_ITEM, Config["继承配置"]["装备1摆放位置"]);
    secondItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_ITEM, Config["继承配置"]["装备2摆放位置"]);
    //获取装备名字
    local firstItemName = PvfItem.GetNameById(firstItemObj.GetIndex());
    local secondItemName = PvfItem.GetNameById(secondItemObj.GetIndex());
    //获取强化信息
    local upgrade = secondItemObj.GetUpgrade();//强化
    //字符串合成
    if (upgrade > 0) {
        secondItemName = "+" + upgrade + " " + secondItemName;
    }
    //组合消息
    local AdMsgObj = AdMsg()
    AdMsgObj.PutType(Config["继承成功提示"]["信息发送位置"]);
    if (Config["继承成功提示"]["信息发送位置"] != 14){
        AdMsgObj.PutString(" ");
    }
    AdMsgObj.PutImoticon(Config["继承成功提示"]["表情"]);
    AdMsgObj.PutString(Config["继承成功提示"]["信息1"]);
    AdMsgObj.PutEquipment("[" + firstItemName + "]", firstItemObj, _InheritBynangua.RarityColor(firstItemIndex));
    AdMsgObj.PutString(Config["继承成功提示"]["信息2"]);
    AdMsgObj.PutEquipment("[" + secondItemName + "]", secondItemObj, _InheritBynangua.RarityColor(secondItemIndex));
    AdMsgObj.Finalize();
    SUser.Send(AdMsgObj.MakePack());
    AdMsgObj.Delete();
}

class _InheritBynangua {
    function CheckUsableLevelBynangua(value) {
        return value >= 0 ? value : -value;
    }
	function NotifyUserAndReturn(SUser, ItemId, message) {
        local Config = GlobalConfig.Get("装备继承券配置_Nangua.json");
		//发送通知
        if(Config["弹窗提示(true为开启,false为关闭)"]) {
            SUser.SendNotiBox(message, 1);
        }else{
            SUser.SendNotiPacketMessage(message, 8);
        }
		//返还消耗的道具
		SUser.GiveItem(ItemId, 1);
	}
    function RarityColor(item_id) {
		local PvfItemObj = PvfItem.GetPvfItemById(item_id);
		if (PvfItemObj == null) {
			return;
		}
		local CItem_get_rarity = PvfItemObj.GetRarity(); // 装备品级
		return _InheritBynangua.rarityColorMap[(CItem_get_rarity).tostring()];
	}
	//品级对应的RGB
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

//加载入口
function _Dps_InheritItem_Main_() {
    _Dps_InheritItem_Logic_();
}

//重载入口
function _Dps_InheritItem_Main_Reload_(OldConfig) {
    local Cofig = GlobalConfig.Get("装备继承券配置_Nangua.json");
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["继承配置"]["继承券道具ID"].tointeger());

    //重新注册
    _Dps_InheritItem_Logic_();
}

function _Dps_InheritItem_Logic_() {
    local Cofig = GlobalConfig.Get("装备继承券配置_Nangua.json");
	// 装备继承
	Cb_Use_Item_Sp_Func[Cofig["继承配置"]["继承券道具ID"]] <- InheritFuncBynangua;
}