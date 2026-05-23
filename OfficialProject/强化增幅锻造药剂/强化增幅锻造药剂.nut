// 强化时使用角色
upgrade_user <- null;
// 强化时使用材料
current_material <- null;
// 锻造时使用角色
Separate_user <- null;
// 强化装备时
function _Dps_Increase_probability_Main_() {
    Cb_WongWork_CItemUpgrade_Enter_Func._Upgrade_Item <- function(args) {
        upgrade_user = User(args[1]);
        local upgrade_info_t = args[3];
        local Upgrade_rand = NativePointer(upgrade_info_t).add(32).readU32();
        // 如果材料是3242则代表增幅，如果是3171则代表强化
        current_material = NativePointer(upgrade_info_t).add(44).readU32();
    }

    // 锻造装备时
    Cb_WongWork_CItemUpgrade_Separate_Enter_Func.Separate_Upgrade <- function(args) {
        Separate_user = User(args[1]);
        local upgrade_info_t = args[3];
        local Upgrade_rand = NativePointer(upgrade_info_t).add(4).readU32();
        local Separate_rand = 10 * Upgrade_rand;
    }
    // 随机值
    Cb_CMTRand_randInt_Leave_Func._Upgrade_Item <- function(args) {
        local address = Haker.NextReturnAddress;
        local Config = GlobalConfig.Get("强化增幅锻造药剂配置_nangua.json");
        if(address == "0x8547768") {
            local rand = args.pop();
            local charac_no = upgrade_user.GetCID().tostring();
            if (current_material == Config["强化药剂"]["强化材料(如你的强化材料是3171,则这里写3171)"] && Sq_CallFunc(S_Ptr("0x865E994"), "int", ["pointer", "int"], upgrade_user.C_Object, Config["强化药剂"]["药剂ID"]) && Config["强化药剂"]["开关(true开启/false关闭)"]) {
                local prob = Config["强化药剂"]["增加概率值"];
                if (Config["强化药剂"]["指定角色概率值"].rawin(charac_no)) {
                    prob = Config["强化药剂"]["指定角色概率值"][charac_no];
                }
                local increase = rand * prob;
                local result = rand + increase;
                if (result > 100000) result = 100000;
                return result;
            }else if (current_material == Config["增幅药剂"]["增幅材料(如你的增幅材料是3242,则这里写3242)"] && Sq_CallFunc(S_Ptr("0x865E994"), "int", ["pointer", "int"], upgrade_user.C_Object, Config["增幅药剂"]["药剂ID"]) && Config["增幅药剂"]["开关(true开启/false关闭)"]) {
                local prob = Config["增幅药剂"]["增加概率值"];
                if (Config["增幅药剂"]["指定角色概率值"].rawin(charac_no)) {
                    prob = Config["增幅药剂"]["指定角色概率值"][charac_no];
                }
                local increase = rand * prob;
                local result = rand + increase;
                if (result > 100000) result = 100000;
                return result;
            }
        }else if(address == "0x811e506" && Config["锻造药剂"]["开关(true开启/false关闭)"]) {
            local rand = args.pop();
            local charac_no = Separate_user.GetCID().tostring();
            if (Sq_CallFunc(S_Ptr("0x865E994"), "int", ["pointer", "int"], Separate_user.C_Object, Config["锻造药剂"]["药剂ID"])) {
                local prob = Config["锻造药剂"]["增加概率值"];
                if (Config["锻造药剂"]["指定角色概率值"].rawin(charac_no)) {
                    prob = Config["锻造药剂"]["指定角色概率值"][charac_no];
                }
                local result = rand / (1 + prob);
                if (result < 1) result = 1;
                return result;
            }
        }
    }
}
