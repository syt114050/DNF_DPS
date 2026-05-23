function _Dps_SetEquipmentUnlockTime_Logic_() {
    local Config = GlobalConfig.Get("设置装备解锁时间_Lenheart.json");
    GameManager.SetItemLockTime(Config["设置装备解锁需要的冷却时间_单位秒"]);
}

function _Dps_SetEquipmentUnlockTime_Main_() {
    _Dps_SetEquipmentUnlockTime_Logic_();
}

function _Dps_SetEquipmentUnlockTime_Main_Reload(OldConfig) {
    _Dps_SetEquipmentUnlockTime_Logic_();
}