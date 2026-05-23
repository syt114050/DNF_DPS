function _Dps_GmConvenienceConsole_Logic_() {
    local Config = GlobalConfig.Get("GM便捷操作台_Lenheart.json");


    Gm_InputFunc_Handle[Config["发送道具指令"]] <- function(SUser, CmdString) {
        local count = -1;
        local pos = 0;
        local handler = [];
        do {
            local start = pos;
            pos = CmdString.find(" ", pos + 1);
            if (pos != null) {
                handler.append(CmdString.slice(start + 1, pos));
            } else
                handler.append(CmdString.slice(start + 1));
            count = count + 1
        } while (pos != null)

        //得到空格数量
        if (count == 1) {
            local Ret = SUser.GiveItem(handler[1].tointeger(), 1);
            if (!Ret) SUser.SendNotiPacketMessage("发送失败背包是不是满了", 8);
        } else if (count == 2) {
            local Ret = SUser.GiveItem(handler[1].tointeger(), handler[2].tointeger());
            if (!Ret) SUser.SendNotiPacketMessage("发送失败背包是不是满了", 8);
        }
    }

    Gm_InputFunc_Handle[Config["转职觉醒指令"]] <- function(SUser, CmdString) {
        local count = -1;
        local pos = 0;
        local handler = [];
        do {
            local start = pos;
            pos = CmdString.find(" ", pos + 1);
            if (pos != null) {
                handler.append(CmdString.slice(start + 1, pos));
            } else
                handler.append(CmdString.slice(start + 1));
            count = count + 1
        } while (pos != null)

        //得到空格数量
        if (count == 1) {
            SUser.ChangeGrowType(handler[1].tointeger(), 0);
            SUser.SendNotiPacket(0, 2, 0);
            SUser.InitSkillW(handler[1].tointeger(), 0);
        } else if (count == 2) {
            SUser.ChangeGrowType(handler[1].tointeger(), handler[2].tointeger());
            SUser.SendNotiPacket(0, 2, 0);
            SUser.InitSkillW(handler[1].tointeger(), handler[2].tointeger());
        }
    }


    Gm_InputFunc_Handle[Config["完成任务指令"]] <- function(SUser, CmdString) {
        local count = -1;
        local pos = 0;
        local handler = [];
        do {
            local start = pos;
            pos = CmdString.find(" ", pos + 1);
            if (pos != null) {
                handler.append(CmdString.slice(start + 1, pos));
            } else
                handler.append(CmdString.slice(start + 1));
            count = count + 1
        } while (pos != null)

        //得到空格数量
        if (count == 1) {
            SUser.ClearQuest_Gm(handler[1].tointeger());
        }
    }

    Gm_InputFunc_Handle[Config["设置等级指令"]] <- function(SUser, CmdString) {
        local count = -1;
        local pos = 0;
        local handler = [];
        do {
            local start = pos;
            pos = CmdString.find(" ", pos + 1);
            if (pos != null) {
                handler.append(CmdString.slice(start + 1, pos));
            } else
                handler.append(CmdString.slice(start + 1));
            count = count + 1
        } while (pos != null)

        //得到空格数量
        if (count == 1) {
            SUser.SetCharacLevel(handler[1].tointeger());
        }
    }

    //获取位置信息
    Gm_InputFunc_Handle[Config["获取位置指令"]] <- function(SUser, CmdString) {
        local Location = SUser.GetLocation();
        SUser.SendNotiPacketMessage("X坐标: " + Location.Pos.X, 8);
        SUser.SendNotiPacketMessage("Y坐标: " + Location.Pos.Y, 8);
        SUser.SendNotiPacketMessage("城镇编号: " + Location.Town, 8);
        SUser.SendNotiPacketMessage("区域编号: " + Location.Area, 8);
    };

    //踢人下线
    Gm_InputFunc_Handle[Config["踢玩家下线指令"]] <- function(SUser, CmdString) {
        local count = -1;
        local pos = 0;
        local handler = [];
        do {
            local start = pos;
            pos = CmdString.find(" ", pos + 1);
            if (pos != null) {
                handler.append(CmdString.slice(start + 1, pos));
            } else
                handler.append(CmdString.slice(start + 1));
            count = count + 1
        } while (pos != null)

        //得到空格数量
        if (count == 1) {
            local TUser = World.GetUserByName(handler[1]);
            if(TUser)TUser.Kick();
        }
    };
}



function _Dps_GmConvenienceConsole_Main_() {
    _Dps_GmConvenienceConsole_Logic_();
}

function _Dps_GmConvenienceConsole_Main_Reload_(OldConfig) {

    foreach (Key,Value in OldConfig) {
        try {
            Gm_InputFunc_Handle.rawdelete(Key);
        } catch (exception){

        }
    }

    _Dps_GmConvenienceConsole_Logic_();
}