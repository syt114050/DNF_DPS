function ResetDimensionInout(SUser, index) {
	local data_manager = Sq_CallFunc(S_Ptr("0x80CC19B"), "pointer");
	local dimensionInout = Sq_CallFunc(S_Ptr("0x0822b612"), "int", ["pointer", "int"], data_manager, index);
	Sq_CallFunc(S_Ptr("0x0822f184"), "int", ["pointer", "int", "int"], SUser.C_Object, index, dimensionInout);
}
function ResetE2DgnFuncBynangua(SUser, ItemId) {
	for (local i = 0; i <= 2; i++) {
		ResetDimensionInout(SUser, i)
	}
	SUser.SendNotiPacketMessage("已重置E2异界地下城次数", 8);
}
function ResetE3DgnFuncBynangua(SUser, ItemId) {
	for (local i = 3; i <= 5; i++) {
		ResetDimensionInout(SUser, i)
	}
	SUser.SendNotiPacketMessage("已重置E3异界地下城次数", 8);
}
//加载入口
function _Dps_MapReset_Main_() {
    _Dps_MapReset_Logic_();
}

//重载入口
function _Dps_MapReset_Main_Reload_(OldConfig) {
    local Cofig = GlobalConfig.Get("异界重置_Lenheart.json");
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["重置E2异界地下城次数"].tointeger());
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig["重置E3异界地下城次数"].tointeger());

    //重新注册
    _Dps_MapReset_Logic_();
}

function _Dps_MapReset_Logic_() {
    local Cofig = GlobalConfig.Get("异界重置_Lenheart.json");
	// E2异界重置券
	Cb_Use_Item_Sp_Func[Cofig["重置E2异界地下城次数"]] <- ResetE2DgnFuncBynangua;
	// E3异界重置券
	Cb_Use_Item_Sp_Func[Cofig["重置E3异界地下城次数"]] <- ResetE3DgnFuncBynangua;
}
