function _Dps_ReforgeEquipment_Main_() {
    local Config = GlobalConfig.Get("重铸券.json");
    //分解券
    Cb_Use_Item_Sp_Func[Config["重铸卷的道具ID"]] <- function(SUser, ItemId) {
        local index = 0;
        local InvenObj = SUser.GetInven();
        if (InvenObj) {
            local ItemObj = InvenObj.GetSlot(1, 9);
            //空装备
            if (ItemObj.IsEmpty) {
                //发送通知
                SUser.SendNotiPacketMessage("装备不存在 请将装备放置在装备栏第一格", 8);
                //返还消耗的道具
                local test = SUser.GiveItem(ItemId, 1);
                return;
            }
            local ItemId1 = ItemObj.GetIndex();
            ItemObj.Delete();

            local item = SUser.GiveItem(ItemId1, 1);


            SUser.SendItemSpace(0);
            SUser.SendNotiPacketMessage("装备重铸", 8);
            if (Config["是否返还分解券道具(true代表返还,false代表不返还)"]) {
                SUser.GiveItem(ItemId, 1);
            }
        }
    };
}