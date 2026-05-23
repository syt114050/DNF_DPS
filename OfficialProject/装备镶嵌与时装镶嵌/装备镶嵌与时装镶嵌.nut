class EquimentUseJewel {

    ExecUser = null;

    //建库建表
    function CreateMysqlTable() {
        local CreateSql1 = "create database if not exists l_equ_jewel default charset utf8;"
        local CreateSql2 = "CREATE TABLE l_equ_jewel.equipment ( equ_id int(11) AUTO_INCREMENT, jewel_data blob NOT NULL,andonglishanbai_flag int(11),date VARCHAR(255), PRIMARY KEY  (equ_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8,AUTO_INCREMENT = 150;"
        local SqlObj = MysqlPool.GetInstance().GetConnect();
        SqlObj.Exec_Sql(CreateSql1);
        SqlObj.Exec_Sql(CreateSql2);
        MysqlPool.GetInstance().PutConnect(SqlObj);
    }

    function api_get_jewel_socket_data(id) { //获取徽章数据,存在返回徽章数据,不存在返回空字节数据
        local CheckSql = "SELECT jewel_data FROM l_equ_jewel.equipment where equ_id = " + id + ";";
        //从池子拿连接
        local SqlObj = MysqlPool.GetInstance().GetConnect();
        local Ret = SqlObj.Select(CheckSql, ["binary"]);
        //把连接还池子
        MysqlPool.GetInstance().PutConnect(SqlObj);
        //没结婚要返回false
        if (Ret.len()< 1 || Ret[0][0] == null) {
            return 0;
        } else {
            return Ret[0][0];
        }
    }

    function api_exitjeweldata(id) { //0代表不存在,存在返回1
        local CheckSql = "SELECT andonglishanbai_flag FROM l_equ_jewel.equipment where equ_id = " + id + ";";
        //从池子拿连接
        local SqlObj = MysqlPool.GetInstance().GetConnect();
        local Ret = SqlObj.Select(CheckSql, ["int"]);
        //把连接还池子
        MysqlPool.GetInstance().PutConnect(SqlObj);
        //没结婚要返回false
        if (Ret.len()< 1 || Ret[0][0] == null) {
            return 0;
        } else {
            return Ret[0][0];
        }
    }

    function save_equiment_socket(socket_data, id) { //0代表不存在,存在返回1
        local CheckSql = "UPDATE l_equ_jewel.equipment SET jewel_data = 0x" + socket_data + " WHERE equ_id = " + id + ";";
        //从池子拿连接
        local SqlObj = MysqlPool.GetInstance().GetConnect();
        local Ret = SqlObj.Select(CheckSql, ["int"]);
        //把连接还池子
        MysqlPool.GetInstance().PutConnect(SqlObj);
        //没结婚要返回false
        if (Ret.len()< 1 || Ret[0][0] == null) {
            return false;
        } else {
            return true;
        }
    }

    function CUser_SendCmdErrorPacket(SUser, id, id2) {
        local Pack = Packet();
        Pack.Put_Header(1, id);
        Pack.Put_Byte(0);
        Pack.Put_Byte(id2);
        Pack.Finalize(true);
        SUser.Send(Pack);
        Pack.Delete();
    }

    function api_PacketBuf_get_buf(packet_buf) {
        return NativePointer(NativePointer(packet_buf).add(20).readPointer()).add(13);
    }

    function add_equiment_socket(equipment_type) { //0代表开孔失败 成功返回标识
        /*
        武器10
        称号11
        上衣12
        头肩13
        下衣14
        鞋子15
        腰带16
        项链17
        手镯18
        戒指19
        辅助装备20
        魔法石21
        */

        /*
        红色:'010000000000010000000000000000000000000000000000000000000000'	A
        黄色:'020000000000020000000000000000000000000000000000000000000000'	B
        绿色:'040000000000040000000000000000000000000000000000000000000000'	C
        蓝色:'080000000000080000000000000000000000000000000000000000000000'	D
        白金:'100000000000100000000000000000000000000000000000000000000000'
        */
        local DB_JewelsocketData = "";
        switch (equipment_type) {
            case 10: //武器10	SS
                DB_JewelsocketData = "100000000000000000000000000000000000000000000000000000000000"
                break;
            case 11: //称号11	SS
                DB_JewelsocketData = "100000000000000000000000000000000000000000000000000000000000"
                break;
            case 12: //上衣12 	C
                DB_JewelsocketData = "040000000000040000000000000000000000000000000000000000000000"
                break;
            case 13: //头肩13	B
                DB_JewelsocketData = "020000000000020000000000000000000000000000000000000000000000"
                break;
            case 14: //下衣14	C
                DB_JewelsocketData = "040000000000040000000000000000000000000000000000000000000000"
                break;
            case 15: //鞋子15	D
                DB_JewelsocketData = "080000000000080000000000000000000000000000000000000000000000"
                break;
            case 16: //腰带16	A
                DB_JewelsocketData = "010000000000010000000000000000000000000000000000000000000000"
                break;
            case 17: //项链17	B
                DB_JewelsocketData = "020000000000020000000000000000000000000000000000000000000000"
                break;
            case 18: //手镯18	D
                DB_JewelsocketData = "080000000000080000000000000000000000000000000000000000000000"
                break;
            case 19: //戒指19	A
                DB_JewelsocketData = "010000000000010000000000000000000000000000000000000000000000"
                break;
            case 20: //辅助装备20	S
                DB_JewelsocketData = "100000000000000000000000000000000000000000000000000000000000"
                break;
            case 21: //魔法石21		S
                DB_JewelsocketData = "100000000000000000000000000000000000000000000000000000000000"
                break;
            default:
                DB_JewelsocketData = "000000000000000000000000000000000000000000000000000000000000"
                break;
        }
        local date = time();
        local Ct = Sq_GetTimestampString();
        date = date.tostring() + Ct;

        local CheckSql = "INSERT INTO l_equ_jewel.equipment (andonglishanbai_flag,jewel_data,date) VALUES(1,0x" + DB_JewelsocketData + ",\'" + date + "\');";
        local CheckSql1 = "SELECT equ_id FROM l_equ_jewel.equipment where date = \'" + date + "\';";
        //从池子拿连接
        local SqlObj = MysqlPool.GetInstance().GetConnect();
        SqlObj.Select(CheckSql, ["int"]);
        local Ret = SqlObj.Select(CheckSql1, ["int"]);
        //把连接还池子
        MysqlPool.GetInstance().PutConnect(SqlObj);
        if (Ret.len()< 1 || Ret[0][0] == null) {
            return 0;
        } else {
            return Ret[0][0];
        }
        return 0;
    }

    function CStackableItem_getJewelTargetSocket(C_Object) {
        return Sq_CallFunc(S_Ptr("0x0822CA28"), "int", ["pointer"], C_Object);
    }

    function CUser_SendUpdateItemList_DB(SUser, Slot, DB_JewelSocketData) {
        local Pack = Packet();
        Pack.Put_Header(0, 14);
        Pack.Put_Byte(0);
        Pack.Put_Short(1);
        local InvenObj = SUser.GetInven();
        Sq_CallFunc(S_Ptr("0x084FC6BC"), "int", ["pointer", "int", "int", "pointer"], InvenObj.C_Object, 1, Slot, Pack.C_Object);
        Pack.Put_BinaryEx(DB_JewelSocketData.C_Object, 30);
        Pack.Finalize(true);
        SUser.Send(Pack);
        Pack.Delete();
    }

    function GetByte(value) {
        local Blob = blob();
        Blob.writen(value, 'w');
        return Blob;
    }

    function intToHex(num) {
        if (num == 0) {
            return "0";
        }
        local hexDigits = "0123456789abcdef";
        local hexString = "";
        while (num > 0) {
            local remainder = num % 16;
            hexString = hexDigits[remainder] + hexString;
            num = (num / 16).tointeger();
        }
        return hexString;
    }

    function lengthCutting(str, ystr, num, maxLength) {
        // 如果字符串长度小于最大长度，在前面补0
        local lengthDiff = maxLength - str.len();
        if (lengthDiff > 0) {
            local zeroPadding = "";
            for (local i = 0; i< lengthDiff; i++) {
                zeroPadding += "0";
            }
            str = zeroPadding + str;
        }
        local strArr = "";
        for (local i = 0; i< str.len(); i += num) {
            local endIndex = i + num;
            if (endIndex > str.len()) {
                endIndex = str.len();
            }
            strArr += str.slice(i, endIndex);
        }
        return ystr + strArr;
    }





    function HackAddSocketToAvatarLogic(Flag) {
        if (Flag) {
            Sq_WriteByteArr(S_Ptr("821A449"), [0x90, 0x90]);
            Sq_WriteByteArr(S_Ptr("0x821A44B"), array(36, 0x90));
        } else {
            Sq_WriteByteArr(S_Ptr("821A449"), [0x74, 0x2B]);
        }
    }



    function FixFunction() {
        //称号回包
        Cb_CTitleBook_putItemData_Leave_Func.EquimentUseJewel <- function(args) {
            local JewelSocketData = api_get_jewel_socket_data(NativePointer(args[3]).add(25).readU32());
            local ret = args.pop();
            if (JewelSocketData && NativePointer(JewelSocketData).add(0).readU8() != 0) {
                local Pack = Packet(args[1]);
                Pack.Put_BinaryEx(JewelSocketData.C_Object, 30);
            }
            return null;
        }.bindenv(this);

        //设计图继承
        Cb_CUsercopyItemOption_Enter_Func.EquimentUseJewel <- function(args) {
            local jewelSocketID = NativePointer(args[2]).add(25).readU32();
            NativePointer(args[1]).add(25).writeU32(jewelSocketID);
            return null;
        }.bindenv(this);

        //装备开孔
        Cb_AddSocketToAvatar_Enter_Func.EquimentUseJewel <- function(args) {
            local SUser = User(args[1]);
            local PackCopyBuffer = Memory.alloc(10001);
            Memory.copy(PackCopyBuffer, NativePointer(args[2]), 1000);
            local Pack = Packet(PackCopyBuffer.C_Object);
            local equ_slot = Pack.GetShort();
            local equitem_id = Pack.GetInt();
            local sta_slot = Pack.GetShort();
            local CurCharacInvenW = SUser.GetInven();
            local inven_item = CurCharacInvenW.GetSlot(1, equ_slot);

            if (equ_slot > 56) { //修改后：大于56则是时装装备   原：如果不是装备文件就调用原逻辑
                equ_slot = equ_slot - 57;
                local C_PacketBuf = api_PacketBuf_get_buf(args[2]) //获取原始封包数据
                C_PacketBuf.add(0).writeShort(equ_slot) //修改掉装备位置信息 时装类镶嵌从57开始。

                //执行原逻辑
                return null;
            }
            //如果已开启镶嵌槽则不执行
            local equ_id = NativePointer(inven_item.C_Object).add(25).readU32();
            if (api_exitjeweldata(equ_id)) {
                CUser_SendCmdErrorPacket(SUser, 209, 19);
                HackAddSocketToAvatarLogic(true);
                return null;
            }

            local item = PvfItem.GetPvfItemById(equitem_id);
            local ItemType = Sq_CallFunc(S_Ptr("0x08514D26"), "int", ["pointer"], item.C_Object);

            if (ItemType == 10) {
                SUser.SendNotiBox("装备为武器类型,不支持打孔!", 1)
                CUser_SendCmdErrorPacket(SUser, 209, 0);
                HackAddSocketToAvatarLogic(true);
                return null;
            } else if (ItemType == 11) {
                SUser.SendNotiBox("装备为称号类型,不支持打孔!", 1)
                CUser_SendCmdErrorPacket(SUser, 209, 0);
                HackAddSocketToAvatarLogic(true);
                return null;
            }

            local id = add_equiment_socket(ItemType);

            Sq_Inven_RemoveItemFormCount(CurCharacInvenW.C_Object, 1, sta_slot, 1, 8, 1); //删除打孔道具
            NativePointer(inven_item.C_Object).add(25).writeU32(id) //写入槽位标识
            SUser.SendUpdateItemList(1, 0, equ_slot);

            local JewelSocketData = api_get_jewel_socket_data(id);
            CUser_SendUpdateItemList_DB(SUser, equ_slot, JewelSocketData); //用于更新镶嵌后的装备显示,这里用的是带镶嵌数据的更新背包函数,并非CUser_SendUpdateItemList

            local Pack = Packet();
            Pack.Put_Header(1, 209);
            Pack.Put_Byte(1);
            Pack.Put_Short(equ_slot + 104);
            Pack.Put_Short(sta_slot);
            Pack.Finalize(true);
            SUser.Send(Pack);
            Pack.Delete();
            HackAddSocketToAvatarLogic(true);
            return null;
        }.bindenv(this);

        Cb_AddSocketToAvatar_Leave_Func.EquimentUseJewel <- function(args) {
            HackAddSocketToAvatarLogic(false);
            return null;
        }.bindenv(this);

        //装备镶嵌和时装镶嵌
        Cb_Dispatcher_UseJewel_Enter_Func.EquimentUseJewel <- function(args) {
            local SUser = User(args[1]);
            local Pack = Packet(args[2]);
            local PackIndex = NativePointer(args[2]).add(4).readInt();
            local State = SUser.GetState();
            if (State != 3) return null;

            local avartar_inven_slot = Pack.GetShort();
            local avartar_item_id = Pack.GetInt();
            local emblem_cnt = Pack.GetByte();

            //下面是参照原时装镶嵌的思路写的。个别点标记出来。
            if (avartar_inven_slot > 104) {
                local equipment_inven_slot = avartar_inven_slot - 104; //取出真实装备所在背包位置值
                local Inven = SUser.GetInven();
                local equipment = Inven.GetSlot(1, equipment_inven_slot);
                //校验是否合法
                if (!equipment || equipment.IsEmpty || (equipment.GetIndex() != avartar_item_id) || SUser.CheckItemLock(1, equipment_inven_slot)) return;

                local id = NativePointer(equipment.C_Object).add(25).readU32();
                local JewelSocketData = api_get_jewel_socket_data(id);
                if (!JewelSocketData) return;

                local emblems = {};
                if (emblem_cnt <= 3) {
                    for (local i = 0; i< emblem_cnt; i++) {
                        local emblem_inven_slot = Pack.GetShort();
                        local emblem_item_id = Pack.GetInt();
                        local equipment_socket_slot = Pack.GetByte();
                        local emblem = Inven.GetSlot(1, emblem_inven_slot);
                        //校验徽章及插槽数据是否合法
                        if (!emblem || emblem.IsEmpty || (emblem.GetIndex() != emblem_item_id) || (equipment_socket_slot >= 3)) return;

                        //校验徽章是否满足时装插槽颜色要求
                        //获取徽章pvf数据
                        local citem = PvfItem.GetPvfItemById(emblem_item_id);
                        if (!citem) return;

                        //校验徽章类型
                        if (!citem.IsStackable() || citem.GetItemType() != 20) return;

                        //获取徽章支持的插槽
                        local emblem_socket_type = CStackableItem_getJewelTargetSocket(citem.C_Object);
                        //获取要镶嵌的时装插槽类型
                        local avartar_socket_type = JewelSocketData.add(equipment_socket_slot * 6).readShort();

                        if (!(emblem_socket_type & avartar_socket_type)) {

                            return;
                        }

                        emblems[equipment_socket_slot] <- [emblem_inven_slot, emblem_item_id];
                    }
                }


                foreach(equipment_socket_slot, emblemObject in emblems) {
                    //删除徽章
                    local emblem_inven_slot = emblemObject[0];
                    Sq_Inven_RemoveItemFormCount(Inven.C_Object, 1, emblem_inven_slot, 1, 8, 1); //删除打孔道具
                    //设置时装插槽数据
                    local emblem_item_id = emblemObject[1];
                    JewelSocketData.add(2 + 6 * equipment_socket_slot).writeU32(emblem_item_id);
                }

                local Buf = Sq_Point2Blob(JewelSocketData.C_Object, 30);
                local Str = "";
                foreach(Value in Buf) {
                    Str += format("%02X", Value);
                }

                save_equiment_socket(Str, id);
                // if (!save_equiment_socket(DB_JewelSocketData, id)) {
                //     print("写入失败了");
                //     return null;
                // }

                CUser_SendUpdateItemList_DB(SUser, equipment_inven_slot, JewelSocketData); //用于更新镶嵌后的装备显示,这里用的是带镶嵌数据的更新背包函数,并非CUser_SendUpdateItemList
                local Pack = Packet();
                Pack.Put_Header(1, 209);
                Pack.Put_Byte(1);
                Pack.Put_Short(equipment_inven_slot + 104);
                Pack.Finalize(true);
                SUser.Send(Pack);
                Pack.Delete();

                return;
            }

            AvatarLogic(args, PackIndex);

            return null;
        }.bindenv(this);

        Cb_Dispatcher_UseJewel_Leave_Func.EquimentUseJewel <- function(args) {
            return -1;
        }.bindenv(this);

        //额外数据包,发送装备镶嵌数据给本地处理
        Cb_InterfacePacketBuf_put_packet_Leave_Func.EquimentUseJewel <- function(args) {
            local ret = args.pop();
            local Inven_Item = NativePointer(args[1]);
            if (Inven_Item.add(1).readU8() == 1) {
                local ItemObj = Item(args[1]);
                local JewelSocketData = api_get_jewel_socket_data(NativePointer(ItemObj.C_Object).add(25).readU32());
                if (JewelSocketData && JewelSocketData.add(0).readU8() != 0) {
                    local Pack = Packet(args[0]);
                    Pack.Put_BinaryEx(JewelSocketData.C_Object, 30);
                }
            }
            return null;
        }.bindenv(this);

        L_HookEquimentUseJewel();
    }




    function WongWork_CAvatarItemMgr_getJewelSocketData(a, b) {
        return Sq_CallFunc(S_Ptr("0x82F98F8"), "pointer", ["pointer", "int"], a, b);
    }

    function CStackableItem_getJewelTargetSocket(C_Object) {
        return Sq_CallFunc(S_Ptr("0x0822CA28"), "int", ["pointer"], C_Object);
    }

    function CInventory_delete_item(C_Object, Type, Slot, Count, Ps, Log) {
        return Sq_CallFunc(S_Ptr("0x850400C"), "int", ["pointer", "int", "int", "int", "int", "int"], C_Object, Type, Slot, Count, Ps, Log);
    }

    function api_set_JewelSocketData(jewelSocketData, slot, emblem_item_id) {
        if (jewelSocketData) {
            NativePointer(jewelSocketData).add(slot * 6 + 2).writeInt(emblem_item_id);
        }
    }

    function DB_UpdateAvatarJewelSlot_makeRequest(a, b, c) {
        return Sq_CallFunc(S_Ptr("0x843081C"), "pointer", ["int", "int", "pointer"], a, b, c);
    }

    //获取时装在数据库中的uid
    function api_get_avartar_ui_id(avartar) {
        return NativePointer(avartar).add(7).readInt();
    }


    function AvatarLogic(args, PackIndex) {
        //角色
        local SUser = User(args[1]);
        //包数据
        local Pack = Packet(args[2]);
        //还原包读取数据号位
        NativePointer(args[2]).add(4).writeInt(PackIndex);

        //校验角色状态是否允许镶嵌
        if (!SUser || SUser.GetState() != 3) {
            return;
        }
        //时装所在的背包槽
        local Inven_Slot = Pack.GetShort();
        //时装item_id
        local Item_Id = Pack.GetInt();
        //本次镶嵌徽章数量
        local Emblem_Count = Pack.GetByte();

        //获取时装道具
        local InvemObj = SUser.GetInven();
        local AvatarObj = InvemObj.GetSlot(2, Inven_Slot);


        //校验时装 数据是否合法
        if (!AvatarObj || AvatarObj.IsEmpty || (AvatarObj.GetIndex() != Item_Id) || SUser.CheckItemLock(2, Inven_Slot)) return;

        local Avartar_AddInfo = AvatarObj.GetAdd_Info();
        //获取时装管理器
        local Inven_AvartarMgr = InvemObj.GetAvatarItemMgr();

        //获取时装插槽数据
        local Jewel_Socket_Data = WongWork_CAvatarItemMgr_getJewelSocketData(Inven_AvartarMgr, Avartar_AddInfo);
        if (!Jewel_Socket_Data) return;

        //最多只支持3个插槽
        if (Emblem_Count <= 3) {
            local emblems = {};

            for (local i = 0; i< Emblem_Count; i++) {
                //徽章所在的背包槽
                local emblem_inven_slot = Pack.GetShort();
                //徽章item_id
                local emblem_item_id = Pack.GetInt();
                //该徽章镶嵌的时装插槽id
                local avartar_socket_slot = Pack.GetByte();

                //获取徽章道具
                local EmblemObje = InvemObj.GetSlot(1, emblem_inven_slot);

                //校验徽章及插槽数据是否合法
                if (!EmblemObje || EmblemObje.IsEmpty || (EmblemObje.GetIndex() != emblem_item_id) || (avartar_socket_slot >= 3)) return;

                //校验徽章是否满足时装插槽颜色要求
                //获取徽章pvf数据
                local citem = PvfItem.GetPvfItemById(emblem_item_id);
                if (!citem) return;

                //校验徽章类型
                if (!citem.IsStackable() || citem.GetItemType() != 20) return;

                //获取徽章支持的插槽
                local emblem_socket_type = CStackableItem_getJewelTargetSocket(citem.C_Object);

                //获取要镶嵌的时装插槽类型
                local avartar_socket_type = NativePointer(Jewel_Socket_Data).add(avartar_socket_slot * 6).readShort();

                if (!(emblem_socket_type & avartar_socket_type)) return;

                emblems[avartar_socket_slot] <- [emblem_inven_slot, emblem_item_id];
            }

            //开始镶嵌
            foreach(avartar_socket_slot, emblemObject in emblems) {
                //删除徽章
                local emblem_inven_slot = emblemObject[0];
                CInventory_delete_item(InvemObj.C_Object, 1, emblem_inven_slot, 1, 8, 1);
                //设置时装插槽数据
                local emblem_item_id = emblemObject[1];
                api_set_JewelSocketData(Jewel_Socket_Data, avartar_socket_slot, emblem_item_id);
            }

            //时装插槽数据存档
            DB_UpdateAvatarJewelSlot_makeRequest(SUser.GetCID(), api_get_avartar_ui_id(AvatarObj.C_Object), Jewel_Socket_Data);

            //通知客户端时装数据已更新
            SUser.SendUpdateItemList(1, 1, Inven_Slot);

            //回包给客户端
            local Pack = Packet();
            Pack.Put_Header(1, 204);
            Pack.Put_Int(1);
            Pack.Finalize(true);
            SUser.Send(Pack);
            Pack.Delete();
        }

        return null;
    }

    constructor() {
        CreateMysqlTable();

        FixFunction();
    }
}

function _Dps_Equ2AvaJewel_Main_() {
    local Config = GlobalConfig.Get("装备镶嵌与时装镶嵌_Lenheart.json");
    local PoolObj = MysqlPool.GetInstance();
    local Ip = Config["数据库IP 不是外置数据库不要更改"];
    local Port = Config["数据库端口 不懂不要更改"];
    local DbName = Config["数据库用户名 本地用户名不懂不要更改"];
    local Password = Config["数据库密码 本地密码不懂不要更改"];
    //设置数据库连接信息
    PoolObj.SetBaseConfiguration(Ip, Port, DbName, Password);
    //连接池大小
    PoolObj.PoolSize = 10;
    //初始化
    PoolObj.Init();
    //装备镶嵌修复
    getroottable()._EquimentUseJewel_Object <- EquimentUseJewel();
}