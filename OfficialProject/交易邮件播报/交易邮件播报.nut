function _Dps_JYYJBB_Main_() {

    Cb_History_ItemUp_Func["交易邮件播报"] <- function(SUser, args) {
        local reason = args[18];
        if (reason == "1") {
            local pvfitem = PvfItem.GetNameById(args[15].tointeger());
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [255, 0, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("获得", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + args[20] + "]", [255, 255, 0]);
            LoginMsgObj.PutColorString("交易的道具", [255, 255, 0]);
            LoginMsgObj.PutColorString(pvfitem, [255, 255, 0]);
            LoginMsgObj.PutColorString(args[17] + "个", [255, 255, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        }
    }




    Cb_History_MoneyUp_Func["交易邮件播报"] <- function(SUser, args) {
        local reason = args[16];
        if (reason == "1") {
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [255, 0, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("获得", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + getFirstBracketContent(args[17]) + "]", [255, 255, 0]);
            LoginMsgObj.PutColorString("交易的", [255, 255, 0]);
            LoginMsgObj.PutColorString(args[15], [255, 255, 0]);
            LoginMsgObj.PutColorString("金币", [255, 255, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        }
    }

    Cb_MailBox11_Send_Leave_Func["交易邮件播报"] <- function(args) {
        local jewelSocketID = NativePointer(args[0]).readPointer();
        local SUser = User(jewelSocketID);
        local name = SUser.GetCharacName();
        local receive_name = NativePointer(args[1]).add(17).readUtf8String();
        local send_gold_count = NativePointer(args[1]).add(46).readU32();
        local send_item_id = NativePointer(args[1]).add(57).readU32();
        local send_item_count = NativePointer(args[1]).add(61).readU32(); //发送道具数量
        local item_name;
        if (send_item_id > 0) {
            item_name = PvfItem.GetNameById(send_item_id);
        }
        // 发送世界公告播报
        if (send_gold_count > 0 && send_item_id > 0) {
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [0, 255, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("刚刚通过邮件向", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + receive_name + "]", [0, 255, 0]);
            LoginMsgObj.PutColorString("发送了", [255, 255, 0]);
            LoginMsgObj.PutColorString("金币*" + send_gold_count, [255, 170, 0]);
            LoginMsgObj.PutColorString("和", [255, 255, 0]);
            LoginMsgObj.PutColorString(send_item_count + "个", [255, 255, 0]);
            LoginMsgObj.PutColorString(item_name, [255, 255, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        } else if (send_gold_count > 0) {
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [0, 255, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("刚刚通过邮件向", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + receive_name + "]", [0, 255, 0]);
            LoginMsgObj.PutColorString("发送了", [255, 255, 0]);
            LoginMsgObj.PutColorString("金币*" + send_gold_count, [255, 170, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        } else if (send_item_id > 0) {
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [0, 255, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("刚刚通过邮件向", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + receive_name + "]", [0, 255, 0]);
            LoginMsgObj.PutColorString("发送了", [255, 255, 0]);
            LoginMsgObj.PutColorString(send_item_count + "个", [255, 255, 0]);
            LoginMsgObj.PutColorString(item_name, [255, 255, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        } else {
            local LoginMsgObj = AdMsg();
            LoginMsgObj.PutType(14);
            LoginMsgObj.PutColorString("玩家[", [255, 255, 0]);
            LoginMsgObj.PutColorString(SUser.GetCharacName(), [0, 255, 0]);
            LoginMsgObj.PutColorString("]", [255, 255, 0]);
            LoginMsgObj.PutColorString("刚刚通过邮件向", [255, 255, 0]);
            LoginMsgObj.PutColorString("[" + receive_name + "]", [0, 255, 0]);
            LoginMsgObj.PutColorString("发送了一封邮件", [255, 255, 0]);
            LoginMsgObj.Finalize();
            World.SendAll(LoginMsgObj.MakePack());
            LoginMsgObj.Delete();
        }
    }
}



function getFirstBracketContent(str) {
    local startPos = str.find("(");
    if (startPos == null) return null;
    local endPos = str.find(")", startPos + 1);
    if (endPos == null) return null;
    // 提取括号内的内容（不包括括号本身）
    return str.slice(startPos + 1, endPos);
}