


function _Dps_CrossBorderStones_Logic_()
{
    local Cofig = GlobalConfig.Get("跨界石_Lenheart.json");

    Cb_Use_Item_Sp_Func[Cofig.CrossoverId.tointeger()] <- function(SUser, ItemId) {
        local Cofig = GlobalConfig.Get("跨界石_Lenheart.json");

        //获取账号金库对象
        local CargoObj = SUser.GetAccountCargo();
        //获取账号金库中的一个空格子
        local EmptySlot = CargoObj.GetEmptySlot();

        //如果没有空格子
        if (EmptySlot == -1) {
            SUser.SendNotiPacketMessage(Cofig.CrossoverStr2, 8);
            //不扣除道具
            Timer.SetTimeOut(function()
            {
                SUser.GiveItem(ItemId, 1);         
            },1);
            return;
        }

        //获取角色背包
        local InvenObj = SUser.GetInven();
        //获取需要转移的装备 这里默认写的装备栏第一个格子
        local ItemObj = InvenObj.GetSlot(Inven.INVENTORY_TYPE_ITEM, 9);
        //获取装备ID
        local EquipId = ItemObj.GetIndex();
        //获取装备名字
        local ItemName = PvfItem.GetNameById(EquipId);
        //获取配置中不可跨界的ID数组
        local NoCrossId = Cofig.NoCrossIdArr;
        //如果这个装备不可跨界
        if (NoCrossId.find(EquipId) != null) {
            SUser.SendNotiPacketMessage(format(Cofig.CrossoverStr5, ItemName), 7);
            //不扣除道具
            Timer.SetTimeOut(function()
            {
                SUser.GiveItem(ItemId, 1);         
            },1);
            return;
        }
        //如果没找到这个格子的装备
        if (!ItemName) {
            SUser.SendNotiPacketMessage(Cofig.CrossoverStr1, 8);
            //不扣除道具
            Timer.SetTimeOut(function()
            {
                SUser.GiveItem(ItemId, 1);         
            },1);
            return;
        }
        //跨界
        local Flag = CargoObj.InsertItem(ItemObj, EmptySlot);
        if (Flag == -1) {
            SUser.SendNotiPacketMessage(Cofig.CrossoverStr3, 8);
            //不扣除道具
            Timer.SetTimeOut(function()
            {
                SUser.GiveItem(ItemId, 1);         
            },1);
        } else {
            //销毁背包中的道具
            ItemObj.Delete();
            //刷新玩家背包列表
            SUser.SendUpdateItemList(1, 0, 9);
            //刷新账号金库列表
            CargoObj.SendItemList();
            SUser.SendNotiPacketMessage(format(Cofig.CrossoverStr4, ItemName), 7);
        }
    }
}



//加载入口
function _Dps_CrossBorderStones_Main_() {
    _Dps_CrossBorderStones_Logic_();
}

//重载入口
function _Dps_CrossBorderStones_Main_Reload_(OldConfig) {
    //先销毁原来注册的
    Cb_Use_Item_Sp_Func.rawdelete(OldConfig.CrossoverId.tointeger());

    //重新注册
    _Dps_CrossBorderStones_Logic_();
}