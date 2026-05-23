/*
文件名:时装与宠物清除卷.nut
路径:OfficialProject/时装与宠物清除卷/时装与宠物清除卷.nut
创建日期:2025-04-01	21:42
文件用途:
*/

function _Dps_FashionAndPetClearanceRoll_Logic_() {
    local Config = GlobalConfig.Get("时装与宠物清除卷_Lenheart.json");
    //宠物删除
    Cb_Use_Item_Sp_Func[Config["宠物清除卷ID"]] <- function(SUser, ItemId) {
        if (Config["宠物清除券是否返还"]) SUser.GiveItem(ItemId, 1);
        local Cid = SUser.GetCID();
        local InvenObj = SUser.GetInven();
        if (InvenObj) {
            for (local i = 0; i <= 13; i++) {
                local ItemObj = InvenObj.GetSlot(3, i);
                local Flag = false;
                if (ItemObj) {
                    deleteCreature(InvenObj, ItemObj);
                    ItemObj.Delete();
                }
            }
            local Sql = "delete from taiwan_cain_2nd.creature_items where charac_no=" + Cid + " and slot < 13 ;";
            local SqlObj = MysqlPool.GetInstance().GetConnect();
            SqlObj.Exec_Sql(Sql);
            //把连接还池子
            MysqlPool.GetInstance().PutConnect(SqlObj);
            SUser.SendItemSpace(7);
            SUser.SendNotiPacketMessage(Config["宠物清除完成提示"], 8);
        }
    }

    //时装删除
    Cb_Use_Item_Sp_Func[Config["时装清除卷ID"]] <- function(SUser, ItemId) {
        if (Config["时装清除券是否返还"]) SUser.GiveItem(ItemId, 1);
        local Cid = SUser.GetCID();
        local InvenObj = SUser.GetInven();
        if (InvenObj) {
            for (local i = 0; i <= 13; i++) {
                local ItemObj = InvenObj.GetSlot(2, i);
                if (ItemObj) {
                    ItemObj.Delete();
                }
            }
            local Sql = "delete from taiwan_cain_2nd.user_items where charac_no=" + Cid + " and slot  >= 10 and slot <= 23";
            local SqlObj = MysqlPool.GetInstance().GetConnect();
            SqlObj.Exec_Sql(Sql);
            //把连接还池子
            MysqlPool.GetInstance().PutConnect(SqlObj);
            SUser.SendItemSpace(1);
            SUser.SendNotiPacketMessage(Config["时装清除完成提示"], 8);
        }
    }
}

function deleteCreature(InvenObj, ItemObj) {
	local creatureMgrPtr = Sq_CallFunc(S_Ptr("0x080dd568"), "pointer", ["pointer"], InvenObj.C_Object);
    if (!creatureMgrPtr)return;
	local creature_UID = NativePointer(ItemObj.C_Object).add(7).readU32();
    if(creature_UID == 0) return;
    Sq_CallFunc(S_Ptr("0x0833A854"), "int", ["pointer", "int"], creatureMgrPtr, creature_UID);
}

function _Dps_FashionAndPetClearanceRoll_Main_() {
    _Dps_FashionAndPetClearanceRoll_Logic_();
}

function _Dps_FashionAndPetClearanceRoll_Main_Reload_(OldConfig) {
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["宠物清除卷ID"]);
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["时装清除卷ID"]);

    _Dps_FashionAndPetClearanceRoll_Logic_();
}
//Timer.SetTimeOut(_Dps_FashionAndPetClearanceRoll_Main_,1)