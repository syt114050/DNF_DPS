/*
文件名:随机附魔.nut
路径:OfficialProject/随机附魔/随机附魔.nut
创建日期:2026-05-18
文件用途:使用随机附魔道具时，将装备上已有的怪物卡片附魔随机替换为同类型卡片池中的另一张。
          遍历背包槽位9~58，找到已附魔装备后写入随机卡片ID并刷新客户端显示。
*/

// 已知的附魔道具ID列表（用于判断装备当前是否已附魔）
local VALID_ENCHANT_IDS = [10002603, 10002604, 10002605, 202404148, 202404149, 202404150, 202404151, 202404152, 202404153];

// 检测当前附魔值是否属于已知附魔类型
function _Dps_RandomEnchant_IsValidBead_(BeadValue) {
    foreach (Id in VALID_ENCHANT_IDS) {
        if (BeadValue == Id) return true;
    }
    return false;
}

// 从卡片池中随机选取一张（可选排除某张卡片）
function _Dps_RandomEnchant_PickCard_(Pool, ExcludeId) {
    if (!Pool || Pool.len() == 0) return -1;
    local Filtered = [];
    foreach (Card in Pool) {
        local CardId = Card.tointeger();
        if (CardId != ExcludeId) Filtered.push(CardId);
    }
    if (Filtered.len() == 0) return Pool[rand() % Pool.len()].tointeger();
    return Filtered[rand() % Filtered.len()];
}

// 获取背包指定槽位的道具对象指针
function _Dps_RandomEnchant_GetInvenRef_(InvenObj, InvenType, Slot) {
    return Sq_CallFunc(S_Ptr("0x84FC1DE"), "pointer", ["pointer", "int", "int"], InvenObj.C_Object, InvenType, Slot);
}

// 读取道具ID（InvenItem对象偏移0处即为item_id）
function _Dps_RandomEnchant_GetItemId_(InvenItemPtr) {
    if (!InvenItemPtr || InvenItemPtr == 0) return 0;
    return NativePointer(InvenItemPtr).add(0).readU32();
}

// 读取装备当前附魔值（偏移13 * 4 = 52字节处）
function _Dps_RandomEnchant_GetBead_(InvenItemPtr) {
    return NativePointer(InvenItemPtr).add(13 * 4).readU32();
}

// 写入新的附魔值
function _Dps_RandomEnchant_SetBead_(InvenItemPtr, BeadId) {
    NativePointer(InvenItemPtr).add(13 * 4).writeU32(BeadId);
}

// 获取提示文本
function _Dps_RandomEnchant_GetText_(Config, Key, DefaultText) {
    if (Config.rawin("提示文本") && Config["提示文本"].rawin(Key))
        return Config["提示文本"][Key];
    return DefaultText;
}

function _Dps_RandomEnchant_Logic_() {
    local Config = GlobalConfig.Get("随机附魔配置.json");
    local EnchantItems = Config["附魔道具列表"];

    foreach (EnchantItemIdStr, EnchantData in EnchantItems) {
        local EnchantItemId = EnchantItemIdStr.tointeger();
        local CardPool = EnchantData["卡片池"];

        Cb_Use_Item_Sp_Func[EnchantItemId] <- function(SUser, ItemId) {
            local CurrentConfig = GlobalConfig.Get("随机附魔配置.json");
            local CurrentPool = CurrentConfig["附魔道具列表"][ItemId.tostring()]["卡片池"];

            local InvenObj = SUser.GetInven();
            if (!InvenObj) {
                SUser.SendNotiPacketMessage(
                    _Dps_RandomEnchant_GetText_(CurrentConfig, "无可用装备", "未找到可附魔的装备"),
                    14
                );
                return;
            }

            local Found = false;
            // 遍历背包槽位 9 ~ 58（与JS版本一致）
            for (local Slot = 9; Slot <= 58 && !Found; Slot++) {
                local InvenItemPtr = _Dps_RandomEnchant_GetInvenRef_(InvenObj, 1, Slot);
                if (!InvenItemPtr || InvenItemPtr == 0) continue;

                local ItemIdAtSlot = _Dps_RandomEnchant_GetItemId_(InvenItemPtr);
                if (ItemIdAtSlot <= 0) continue;

                local CurrentBead = _Dps_RandomEnchant_GetBead_(InvenItemPtr);
                if (!_Dps_RandomEnchant_IsValidBead_(CurrentBead)) continue;

                // 从卡片池中随机选一张（排除当前附魔值对应的物品ID）
                local NewCard = _Dps_RandomEnchant_PickCard_(CurrentPool, ItemId);
                if (NewCard < 0) {
                    SUser.SendNotiPacketMessage(
                        _Dps_RandomEnchant_GetText_(CurrentConfig, "卡片池为空", "没有找到可用附魔卡片"),
                        14
                    );
                    return;
                }

                // 写入新附魔值
                _Dps_RandomEnchant_SetBead_(InvenItemPtr, NewCard);
                Found = true;

                // 刷新背包显示
                SUser.SendNotiPacketMessage(
                    _Dps_RandomEnchant_GetText_(CurrentConfig, "附魔成功", "随机附魔成功！"),
                    8
                );
            }

            if (!Found) {
                SUser.SendNotiPacketMessage(
                    _Dps_RandomEnchant_GetText_(CurrentConfig, "无可用装备", "未找到可附魔的装备，请确认背包中存在已附魔的装备。"),
                    14
                );
            }
        }
    }
}

function _Dps_RandomEnchant_Main_() {
    _Dps_RandomEnchant_Logic_();
}

function _Dps_RandomEnchant_Main_Reload_(OldConfig) {
    local OldItems = OldConfig["附魔道具列表"];
    foreach (EnchantItemIdStr, EnchantData in OldItems) {
        local OldId = EnchantItemIdStr.tointeger();
        if (Cb_Use_Item_Sp_Func.rawin(OldId)) Cb_Use_Item_Sp_Func.rawdelete(OldId);
    }
    _Dps_RandomEnchant_Logic_();
}
