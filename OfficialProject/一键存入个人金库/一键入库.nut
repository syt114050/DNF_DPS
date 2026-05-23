/*
文件名:一键入库.nut
路径:MyProject/一键入库.nut
创建日期:2025-03-25	14:42
文件用途:一键入库
*/

function _Dps_OneClickStorage_Logic_() {
    local Config = GlobalConfig.Get("一键存入个人金库_Lenheart.json");
    //在游戏中输入//一键入库即可调用
    Gm_InputFunc_Handle[Config["一键存仓命令"]] <- function(SUser, Cmd) {
        // 获取角色背包
        local InvenObj = SUser.GetInven();
        // 角色仓库
        local CargoObj = Sq_CallFunc(S_Ptr("0x08151a94"), "pointer", ["pointer"], SUser.C_Object);
        // 添加计数器
        local transferCount = 0;
        // 遍历背包消耗品栏及材料栏
        for (local i = 57; i <= 152; ++i) {
            // 获取背包物品
            local ItemObj = InvenObj.GetSlot(1, i);
            // 获取背包物品ID
            local Item_Id = ItemObj.GetIndex();
            local ItemName = PvfItem.GetNameById(Item_Id);
            // 如果物品ID为0或3037，跳过(在此可以添加其他需要跳过的物品ID)
            if (Item_Id == 0 || Config["指定道具ID不存入"].find(Item_Id) != null) {
                continue;
            }

            // 角色仓库是否存在背包物品
            local CargoSlot = Sq_CallFunc(S_Ptr("0x850bc14"), "int", ["pointer", "int"], CargoObj, Item_Id);
            // 如果角色仓库中没有该物品，跳过
            if (CargoSlot == -1) {
                continue;
            }

            // 获取仓库物品指针
            local cargoItemPointer = NativePointer(CargoObj).add(4).readPointer();
            // 获取角色仓库物品对象
            local cargoItemObj = NativePointer(cargoItemPointer).add(61 * CargoSlot);
            // 获取角色仓库物品ID
            local cargoItemId = NativePointer(cargoItemPointer).add(61 * CargoSlot + 2).readU32();
            // 获取角色仓库物品数量
            local cargoItemCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], cargoItemObj.C_Object);

            // 获取物品对象
            local PvfItem = PvfItem.GetPvfItemById(cargoItemId);

            // 获取物品可堆叠数量
            local getStackableLimit = Sq_CallFunc(S_Ptr("0x0822C9FC"), "int", ["pointer"], PvfItem.C_Object);

            // 如果仓库已达堆叠上限，跳过此物品
            if (cargoItemCount >= getStackableLimit) {
                continue;
            }

            // 获取背包物品数量
            local inventoryItemCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], ItemObj.C_Object);
            // 获取物品是否可堆叠
            local checkStackableLimit = Sq_CallFunc(S_Ptr("0x08501A79"), "int", ["int", "int"], cargoItemId, cargoItemCount + inventoryItemCount);
            // 尝试将物品储存至角色仓库中
            local tryAddStackItem = Sq_CallFunc(S_Ptr("0x0850B4B0"), "int", ["pointer", "pointer", "int"], CargoObj, ItemObj.C_Object, CargoSlot);
            if (tryAddStackItem >= 0) {
                // 正式将物品插入角色仓库中
                Sq_CallFunc(S_Ptr("0x850b672"), "pointer", ["pointer", "pointer", "int"], CargoObj, ItemObj.C_Object, CargoSlot);
                // 删除背包中的物品
                ItemObj.Delete();
                transferCount++;
                SUser.SendNotiPacketMessage("[ " + ItemName + " ]" + "成功入库 x " + inventoryItemCount, 8);
            }

            // 处理可堆叠物品
            if (checkStackableLimit == 0) {
                // 获取物品总数
                local totalCount = cargoItemCount + inventoryItemCount;

                // 如果总数不超过上限，全部堆到仓库
                if (totalCount <= getStackableLimit) {
                    // 将物品堆到仓库
                    Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], cargoItemObj.C_Object, totalCount);
                    // 删除背包中的物品
                    ItemObj.Delete();
                    transferCount++;
                    SUser.SendNotiPacketMessage("[ " + ItemName + " ]" + "成功入库 x " + inventoryItemCount, 8);
                } else {
                    // 如果总数超过上限
                    // 将仓库的物品数量设置为最大数量
                    Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], cargoItemObj.C_Object, getStackableLimit);
                    // 将背包数量减去转移至仓库的数量
                    local transferAmount = getStackableLimit - cargoItemCount;
                    Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, totalCount - getStackableLimit);
                    transferCount++;
                    SUser.SendNotiPacketMessage("[ " + ItemName + " ]" + "成功入库 x " + transferAmount, 8);
                }
            }

            // 通知客户端更新背包
            SUser.SendUpdateItemList(1, 0, i);
        }

        if (transferCount == 0) {
            SUser.SendNotiBox("没有可转移的物品！", 1);
        }
        // 通知客户端更新仓库
        SUser.SendItemSpace(2);
    }
}
//启动函数 自定义的需要写在ifo中
function _Dps_OneClickStorage_Main_() {
    _Dps_OneClickStorage_Logic_();
}

function _Dps_OneClickStorage_Main_Reload(OldConfig) {
    Gm_InputFunc_Handle.rawdelete(OldConfig["一键存仓命令"]);
    _Dps_OneClickStorage_Logic_();
}