/*
文件名:史诗药剂.nut
路径:MyProject/史诗药剂.nut
创建日期:2025-03-28	10:21
文件用途:史诗药剂
*/

//启动函数 自定义的需要写在ifo中
function _Dps_EpicPotion_Main_() {
    //注册获取道具稀有度进入回调
    Cb_GetItemRarity_Enter_Func["史诗药剂_逻辑"] <- function(args) {
		// print("获取道具稀有度进入回调");
        local Cofig = GlobalConfig.Get("史诗药剂配置文件.json");
        local Addr = NativePointer(args[0]);
        local VectorSize = (Addr.add(4).readU32() - Addr.readU32()) / 4;
        // 遍历队伍成员，找到使用了史诗药剂的玩家
        local userWithPotion = null;
        for (local i = 0; i< VectorSize; i++) {
            local elementAddr = NativePointer(Addr.readPointer()).add(i * 4);
            local user = elementAddr.readPointer();
            if (user && Sq_CallFunc(S_Ptr("0x865E994"), "int", ["pointer", "int"], user, Cofig["史诗药剂ID"])) {
                userWithPotion = User(user);
                break;
            }
        }
        if (userWithPotion && Haker.NextReturnAddress == "0x853583a") {
            local partyobj = userWithPotion.GetParty();
            // 检查是否单人
            if (Sq_CallFunc(S_Ptr("0x0859A16A"), "int", ["pointer", ], partyobj.C_Object) == 1) {
                local MaxRoll = NativePointer(args[1]).add(16).readU32();
                local odds = Cofig["史诗药剂默认加成几率"]; // 默认药剂的增加几率
                // 检查是否VIP玩家
                local charac_no = userWithPotion.GetCID();
                local cfg = Cofig["指定角色ID额外叠加加成几率"];
                local key = charac_no.tostring();
                if (cfg != null && cfg.rawin(key)) {
                    odds = cfg[key];
                    //print("VIP玩家:" + key + " 加成几率:" + odds);
                }
                // 计算新的roll值
                args[2] = MathClass.getMin(args[2] + args[2] * odds, MaxRoll);
                // print("新的roll值:" + args[2] + " 加成几率:" + odds + " 最大roll值:" + MaxRoll + " 角色ID:" + charac_no);
            }
        }
        return args;
    }
}