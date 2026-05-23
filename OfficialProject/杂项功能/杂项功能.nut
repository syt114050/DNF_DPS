function _Dps_sundry_nangua_Main_() {
    local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
    if(config["杂项功能开关"]["摆摊开启两排格子"]){
        NativePointer(S_Ptr("0x085C6EB8")).writeByteArray([0x66, 0x83, 0xF8, 0x0E]);
        // 超过10个邮件时自动分开发送
        Cb_ReqDBSendNewSystemMultiMail_Leave_Func._SendNewSystemMultiMail <- function(args) {
            local num = args[2];
            if (num > 10) {
                Sq_CallFunc(S_Ptr("0x8556B68"), "int", ["pointer", "pointer", "int", "int", "int", "pointer", "int", "int", "int", "int"],
                    args[0], args[1], 10, args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
                local left = num - 10;
                local pack = Memory.alloc(0x1000);
                for(local i = 0; i < left; i++){
                    Memory.copy(pack.add(61 * i), NativePointer(args[1]).add(61 * (i + 10)), 61);
                }
                Sq_CallFunc(S_Ptr("0x8556B68"), "int", ["pointer", "pointer", "int", "int", "int", "pointer", "int", "int", "int", "int"],
                    args[0], pack.C_Object, left, args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
            }
        }
    }

    // 设置最大等级
    if(config["杂项功能开关"]["设置最高等级"][0]){
        local level = config["杂项功能开关"]["设置最高等级"][1];
        GameManager.SetGameMaxLevel(level);
    }

    // 装备解锁时间
    if(config["杂项功能开关"]["装备解锁(单位:秒)"][0]){
        local time = config["杂项功能开关"]["装备解锁(单位:秒)"][1];
        GameManager.SetItemLockTime(time);
    }

    // 创建缔造者
    if(config["杂项功能开关"]["创建缔造者"]){
        GameManager.OpenCreateJob_CreatorMage();
    }

    // 自动解除魔法封印
    if(config["杂项功能开关"]["自动解除魔法封印"]){
        GameManager.OpenRandomAutomaticUnblocking();
    }

    // 开启装备与时装镶嵌
    if(config["杂项功能开关"]["开启装备与时装镶嵌"]){
        GameManager.FixEquipUseJewel();
    }

    // 修复下线卡城镇
    if(config["杂项功能开关"]["修复下线卡城镇"]){
        GameManager.FixSaveTown();
    }

    // 修复绝望之塔金币异常
    if(config["杂项功能开关"]["修复绝望之塔金币异常"]){
        GameManager.FixDespairGold();
    }

    // 绝望之塔通关后可以用门票继续进入
    if(config["杂项功能开关"]["绝望之塔通关后可以用门票继续进入"]){
        Sq_WriteByteArr(S_Ptr("0x0864416F"), [0xEB, 0x47]);
    }

    // 修复绝望之塔每10层进不去副本
    Cb_TowerOfDespairMgr_SendAPCInfo_Enter_Func._TowerOfDespair <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if(config["杂项功能开关"]["修复绝望之塔每10层进不去副本"]){
            local this_ptr = args[0];
            local tod_layer = args[1];
            local user = args[2];
            local apc_mgr = NativePointer(this_ptr).add(213 * 4).readPointer();
            local layer = NativePointer(tod_layer).readU16();
            local apc_info = Memory.alloc(0x100000);
            local new_tod_layer = Memory.alloc(2);
            new_tod_layer.writeU16(layer);
            Sq_CallFunc(S_Ptr("0x085FED2E"), "void", ["pointer", "pointer", "pointer"], apc_mgr, new_tod_layer.C_Object, apc_info.C_Object);
        }
    }

    // 设置每日可交易金币上限值
    if(config["杂项功能开关"]["设置每日可交易金币上限值"][0]){
        local max = config["杂项功能开关"]["设置每日可交易金币上限值"][1];
        GameManager.FixGlodTradeDaily(max);
    }

    // 强化13以上免刷新
    if(config["杂项功能开关"]["强化13以上免刷新"]){
        GameManager.Fix_13Upgrade();
    }

    // 开启14格技能栏
    if(config["杂项功能开关"]["开启14格技能栏"]){
        GameManager.Fix14Skill();
    }

    // 修复拍卖行消耗品上架
    if(config["杂项功能开关"]["修复拍卖行消耗品上架"]){
        GameManager.Fix_Auction_Regist_Item();
    }

    // 副本内可丢弃物品品级
    if(config["杂项功能开关"]["副本内可丢弃物品品级(开启后可丢弃粉装,3为装备品级)"][0]){
        local level = config["杂项功能开关"]["副本内可丢弃物品品级(开启后可丢弃粉装,3为装备品级)"][1];
        GameManager.FixDungeonDropGrade(level);
    }

    // 发送邮件时验证关闭
    if(config["杂项功能开关"]["发送邮件时验证关闭"]){
        GameManager.FixEmailRemovalVerification();
    }

    // 关闭商店回购
    Cb_Item_IsBanRedeemItem_Leave_Func.BanRedeemItemByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if (config["杂项功能开关"]["关闭商店回购"]) {
            return 1;
        }
    }

    // 无视创建角色时间直接删除角色
    Cb_User_CheckDeleteCharacTime_Leave_Func.DeleteCharacByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if (config["杂项功能开关"]["无视创建角色时间直接删除角色"]) {
            return 1;
        }
    }

    // 忽略在副本门口禁止摆摊
    Cb_CPrivateStore_IsAreaNearEntranceDungeon_Leave_Func.PrivateStoreByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if (config["杂项功能开关"]["忽略在副本门口禁止摆摊"]) {
            return 1;
        }
    }

    // 脱离公会后可立马加入新公会
    Cb_MonitorNoticeGuildSecede_dispatch_Enter_Func.DeleteSecedeByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if (config["杂项功能开关"]["脱离公会后可立马加入新公会"]) {
            local SUser = User(args[1]);
            local charac_no = SUser.GetCID();
    		local updateQuery = "UPDATE d_guild.guild_member SET secede_time = '0000-00-00 00:00:00' where charac_no=" + charac_no + ";";
    		local column_type_list = ["int"];
    		local SqlObj = MysqlPool.GetInstance().GetConnect();
    		SqlObj.Select(updateQuery, column_type_list);
            MysqlPool.GetInstance().PutConnect(SqlObj);
        }
    }

    //公会普通信息互通
    Cb_MonitorNoticeGuildChatMsg_Leave_Func.GUildMessagetoCommonByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        if (config["杂项功能开关"]["公会聊天互通"]) {
            local SUser = User(args[1]);
            local msgData = args[2];

            local senderName = NativePointer(msgData).add(18).readUtf8String();
            if (SUser.GetCharacName() == senderName) {
                local Guild_name = SUser.GetGuildName();
                _Dps_GuildmsgBynangua_Main_.SendMessagetoCommon(msgData, Guild_name);
            }
        }
    }
    //公会超链接信息互通
    Cb_MonitorNoticeGuildChatMsgHyperLink_Leave_Func.GUildMessagetoHyperLinkByNangua <-  function(args) {
        local config = GlobalConfig.Get("杂项功能开关_Nangua.json");
        local SUser = User(args[1]);
        local msgData = args[2];

        local senderName = NativePointer(msgData).add(18).readUtf8String();
        if (config["杂项功能开关"]["公会聊天互通"] && SUser.GetCharacName() == senderName) {
            local guild_name = SUser.GetGuildName();
            local Pack = _Dps_GuildmsgBynangua_Main_.SendMessagetoHyperLink(msgData, guild_name);
            local users = World.GetOnlinePlayer();
            users.apply(function(Value) {
                local onguildName = Value.GetGuildName()
                local guildkey = Sq_CallFunc(S_Ptr("0x822F46C"), "int", ["pointer"], Value.C_Object);
                if (onguildName != guild_name && guildkey > 0) {
                    Value.Send(Pack);
                }
            });
            Pack.Delete();
        }
    }

    class _Dps_GuildmsgBynangua_Main_ {
        function SendMessagetoCommon(msg, guild_name) {
            local Pack = Packet();
            Pack.Put_Header(0, 65);
            Pack.Put_Byte(6);
            Pack.Put_Byte(0);
            local name = NativePointer(msg).add(18).readUtf8String();
            _Dps_GuildmsgBynangua_Main_.api_InterfacePacketBuf_put_string(Pack, name);
            Pack.Put_Byte(0);
            local msgLen = NativePointer(msg).add(0x30).readU8();
            local content = NativePointer(msg).add(0x31);
            local extraMsg = " [" + guild_name + "]跨公会信息";
            local extraContent = Memory.allocUtf8String(extraMsg);
            local extraLen = extraMsg.len();
            local newMsgLen = msgLen + extraLen;
            Pack.Put_Int(newMsgLen)
            Pack.Put_BinaryEx(content.C_Object, msgLen);
            Pack.Put_BinaryEx(extraContent.C_Object, extraLen);
            Pack.Put_Byte(0);
            Pack.Finalize(true);
            local users = World.GetOnlinePlayer();
            users.apply(function(Value) {
                local onguildName = Value.GetGuildName()
                local guildkey = Sq_CallFunc(S_Ptr("0x822F46C"), "int", ["pointer"], Value.C_Object);
                if (onguildName != guild_name && guildkey > 0) {
                    Value.Send(Pack);
                }
            });
            Pack.Delete();
        }

        function SendMessagetoHyperLink(msg, guild_name) {
            local Pack = Packet();
            Pack.Put_Header(0, 371);
            Pack.Put_Byte(6);
            Pack.Put_Byte(0);
            // 角色名
            local name = NativePointer(msg).add(18).readUtf8String();
            _Dps_GuildmsgBynangua_Main_.api_InterfacePacketBuf_put_string(Pack, name);
            Pack.Put_Byte(0);
            local msgLen = NativePointer(msg).add(361).readU8();
            local content = NativePointer(msg).add(362);
            local extraMsg = " [" + guild_name + "]跨公会信息";
            local extraContent = Memory.allocUtf8String(extraMsg);
            local extraLen = extraMsg.len();
            local newMsgLen = msgLen + extraLen;
            Pack.Put_Int(newMsgLen)
            Pack.Put_BinaryEx(content.C_Object, msgLen);
            Pack.Put_BinaryEx(extraContent.C_Object, extraLen);

            local itemCount = NativePointer(msg).add(48).readU8();
            Pack.Put_Byte(itemCount);
            for (local i = 0; i < itemCount; i++) {
                Pack.Put_BinaryEx(NativePointer(msg).add(104 * i + 49).C_Object, 104);
            }
            Pack.Finalize(true);
            return Pack;
        }
        function api_InterfacePacketBuf_put_string(Pack, s) {
            local p = Memory.allocUtf8String(s);
            local len = s.len();
            Pack.Put_Int(len);
            Pack.Put_BinaryEx(p.C_Object, len);
        }
    }
}