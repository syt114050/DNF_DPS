function _Dps_RepairEquipment_Main_() {
    Cb_StartGame_check_error_Enter_Func.info <- function (args) {
        local config = GlobalConfig.Get("自动修理装备配置_nangua.json");
        local SUser = User(args[1]);
        if(!config["自动修理装备开关(true开启/false关闭)"]) {
            return;
        }

        local PartyObj = SUser.GetParty();
        local needCheckContract = config["指定契约才可修理(true开启/false关闭)"];

        if(PartyObj) {
            for (local i = 0; i < 4; ++i) {
                local TUser = PartyObj.GetUser(i);
                if(TUser) {
                    if(needCheckContract) {
                        if(_Dps_RepairEquipment.CheckUserPremium(TUser, config["契约ID"])) {
                            _Dps_RepairEquipment.RepairEquipmentBynangua(TUser);
                        }
                    } else {
                        _Dps_RepairEquipment.RepairEquipmentBynangua(TUser);
                    }
                }
            }
        } else {
            if(needCheckContract) {
                if(_Dps_RepairEquipment.CheckUserPremium(SUser, config["契约ID"])) {
                    _Dps_RepairEquipment.RepairEquipmentBynangua(SUser);
                }
            } else {
                _Dps_RepairEquipment.RepairEquipmentBynangua(SUser);
            }
        }
    }
}

class _Dps_RepairEquipment {
    // 检查用户是否拥有指定契约
    function CheckUserPremium(SUser, contract_id) {
        local premium_ptr = Sq_CallFunc(S_Ptr("0x0812CE28"), "pointer", ["pointer"], SUser.C_Object);
        local contract_data_ptr = Sq_CallFunc(S_Ptr("0x086ADF52"), "pointer", ["pointer", "int"], premium_ptr, contract_id);
        local VIP = NativePointer(contract_data_ptr).readU32() != 0;
        return VIP;
    }
    function RepairEquipmentBynangua(SUser) {
        local config = GlobalConfig.Get("自动修理装备配置_nangua.json");
        local InvenObj = SUser.GetInven();
        local anyItemRepaired = false;
        local current_money = InvenObj.GetMoney();
        local need_repair_count = 0;
        local repaired_count = 0;
        local total_repair_cost = 0;

        // 第一次遍历：计算总修理费用和需要修理的装备数量
        for (local i = 10; i <= 16; ++i) {
            if (i == 11) continue;
            local ItemObj = InvenObj.GetSlot(0, i);
            if (ItemObj.GetIndex() == 0) continue;

            local durability = ItemObj.GetDurable();
            local G_CDataManager = Sq_CallFunc(S_Ptr("0x80CC19B"), "pointer", []);
            local PVFItemObj = Sq_CallFunc(S_Ptr("0x835FA32"), "pointer", ["pointer", "int"], G_CDataManager, ItemObj.GetIndex());
            local durability_max = Sq_CallFunc(S_Ptr("0x811ED98"), "int", ["pointer"], PVFItemObj);

            if (durability < durability_max) {
                need_repair_count++;
                local charac_level = SUser.GetCharacLevel();
                local growth_grade = Sq_CallFunc(S_Ptr("0x085137B8"), "int", ["pointer", "int"], PVFItemObj, charac_level);
                local growth_repair_cost = Sq_CallFunc(S_Ptr("0x0851381C"), "int", ["pointer", "int"], PVFItemObj, charac_level);
                local cost_rate = 1.0;
                local repair_cost = Sq_CallFunc(S_Ptr("0x0898C8FC"), "int", ["int", "int", "int", "int", "bool", "float"], growth_repair_cost, durability, durability_max, growth_grade, false, cost_rate);
                total_repair_cost += repair_cost;
            }
        }

        if (need_repair_count == 0) return;

        // 如果开启了返还功能，先给玩家发放金币
        if(config["是否返还修理费用(true返还/false不返还)"]) {
            SUser.RechargeMoney(total_repair_cost);
            SUser.SendUpdateItemList(1, 0, 0);
            current_money = InvenObj.GetMoney(); // 更新当前金币数
        }

        local msg_base = Memory.alloc(32);
        local param_base = Memory.alloc(32);
        local dispatcher = Memory.alloc(4);

        for (local i = 10; i <= 16; ++i) {
            if (i == 11) continue;

            local ItemObj = InvenObj.GetSlot(0, i);
            if (ItemObj.GetIndex() == 0) continue;

            local durability = ItemObj.GetDurable();
            local G_CDataManager = Sq_CallFunc(S_Ptr("0x80CC19B"), "pointer", []);
            local PVFItemObj = Sq_CallFunc(S_Ptr("0x835FA32"), "pointer", ["pointer", "int"], G_CDataManager, ItemObj.GetIndex());
            local durability_max = Sq_CallFunc(S_Ptr("0x811ED98"), "int", ["pointer"], PVFItemObj);

            if (durability < durability_max) {
                local charac_level = SUser.GetCharacLevel();
                local growth_grade = Sq_CallFunc(S_Ptr("0x085137B8"), "int", ["pointer", "int"], PVFItemObj, charac_level);
                local growth_repair_cost = Sq_CallFunc(S_Ptr("0x0851381C"), "int", ["pointer", "int"], PVFItemObj, charac_level);
                local cost_rate = 1.0;
                local repair_cost = Sq_CallFunc(S_Ptr("0x0898C8FC"), "int", ["int", "int", "int", "int", "bool", "float"], growth_repair_cost, durability, durability_max, growth_grade, false, cost_rate);

                if (current_money < repair_cost) {
                    continue;
                }

                local temp_ptr = msg_base;
                temp_ptr = temp_ptr.add(13);
                temp_ptr.writeU8(3);
                temp_ptr = msg_base.add(14);
                temp_ptr.writeU16(i);
                temp_ptr = msg_base.add(16);
                temp_ptr.writeU16(65535);
                temp_ptr = param_base.add(12);
                temp_ptr.writeU16(0);

                local result = Sq_CallFunc(S_Ptr("0x081C6082"), "int", ["pointer", "pointer", "pointer", "pointer"], dispatcher.C_Object, SUser.C_Object, msg_base.C_Object, param_base.C_Object);

                if(result == 0) {
                    anyItemRepaired = true;
                    repaired_count++;
                    SendRepairPacket(SUser, i, durability_max);
                    current_money -= repair_cost;
                }
            }
        }

        if (config["是否开启修理后发送提示(true开启/false关闭)"]) {
            if (repaired_count == 0) {
                SUser.SendNotiPacketMessage(config["修理失败提示"], config["发送信息播报位置"]);
            } else if (repaired_count < need_repair_count) {
                SUser.SendNotiPacketMessage(config["修理部分装备提示"], config["发送信息播报位置"]);
            } else {
                SUser.SendNotiPacketMessage(config["修理成功提示"], config["发送信息播报位置"]);
            }
        }
    }
}
function SendRepairPacket(SUser, slot, durability) {
    local Pack = Packet();
    Pack.Put_Header(1, 25);
    Pack.Put_Byte(1);
    local InvenObj = SUser.GetInven();
    local Money = InvenObj.GetMoney();
    Pack.Put_Int(Money);
    Pack.Put_Byte(0);
    Pack.Put_Short(slot);
    Pack.Put_Short(durability);
    Pack.Finalize(true);
    SUser.Send(Pack);
    Pack.Delete();
}