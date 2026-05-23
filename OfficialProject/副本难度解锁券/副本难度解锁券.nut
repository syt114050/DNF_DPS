function _Dps_unlock_all_dgn_diff_Main_() {
    local Cofig = GlobalConfig.Get("副本难度解锁_Nangua.json");
    Cb_Use_Item_Sp_Func[Cofig["副本难度解锁券道具ID"]] <- function(SUser, ItemId) {
        local a3 = Memory.allocUtf8String("3");
        Sq_CallFunc(S_Ptr("0x0820BA90"), "int", ["pointer", "int", "pointer"], SUser.C_Object, 120, a3.C_Object);

        Timer.SetTimeOut(function(SUser) {
            Sq_CallFunc(S_Ptr("0x8686FEE"), "int", ["pointer", "int"], SUser.C_Object, 1);
        }, 1, SUser);
        SUser.SendNotiPacketMessage(Cofig["解锁成功提示信息"], 8);
    }
}
