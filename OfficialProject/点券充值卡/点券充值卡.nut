function handleCeraCardBynangua(SUser, ItemId) {
    local Config = GlobalConfig.Get("点券充值卡配置_Nangua.json");
    local ItemIdStr = ItemId.tostring();

    if (Config["充值卡配置"].rawin(ItemIdStr)) {
        local CeraAmount = Config["充值卡配置"][ItemIdStr];
        SUser.RechargeCera(CeraAmount);
        if (Config["启用233发包(true/false)"]) {
            SUser.SendNotiBox(format(Config["充值成功提示"], CeraAmount), 1);
        }else{
            SUser.SendNotiPacketMessage(format(Config["充值成功提示"], CeraAmount), 8);
        }
    }
}

//加载入口
function _Dps_handleCeraCard_Main_() {
    _Dps_handleCeraCard_Logic_();
}

//重载入口
function _Dps_handleCeraCard_Main_Reload_(OldConfig) {
    local Config = GlobalConfig.Get("点券充值卡配置_Nangua.json");
    // 删除旧的注册
    foreach(itemId, _ in OldConfig["充值卡配置"]) {
        Cb_Use_Item_Sp_Func.rawdelete(itemId.tointeger());
    }
    //重新注册
    _Dps_handleCeraCard_Logic_();
}

function _Dps_handleCeraCard_Logic_() {
    local Config = GlobalConfig.Get("点券充值卡配置_Nangua.json");
    // 注册所有充值卡
    foreach(itemId, _ in Config["充值卡配置"]) {
        Cb_Use_Item_Sp_Func[itemId.tointeger()] <- handleCeraCardBynangua;
    }
}