/*
文件名:多倍泡点.nut
路径:OfficialProject/多倍泡点/多倍泡点.nut
创建日期:2026-05-21
文件用途:定时检测在线玩家，持有指定物品且在指定城镇区域挂机时可获得多倍泡点及随机大奖(权重抽奖+全服公告)
*/

// ========== 辅助函数 ==========

function _Dps_MultiBonus_Roll_(Pool) {
    if (!Pool || Pool.len() == 0) return -1;
    local totalWeight = 0;
    foreach (item in Pool) {
        local w = item[1].tointeger();
        if (w < 0) w = 0;
        totalWeight += w;
    }
    if (totalWeight <= 0) return -1;
    local roll = rand() % totalWeight;
    local acc = 0;
    for (local i = 0; i < Pool.len(); i++) {
        local w = Pool[i][1].tointeger();
        if (w <= 0) continue;
        acc += w;
        if (roll < acc) return i;
    }
    return -1;
}

function _Dps_MultiBonus_Replace_(Str, From, To) {
    local result = "";
    local pos = 0;
    local found = Str.find(From, pos);
    while (found != null) {
        result += Str.slice(pos, found) + To;
        pos = found + From.len();
        found = Str.find(From, pos);
    }
    result += Str.slice(pos);
    return result;
}

function _Dps_MultiBonus_GiveItem_(SUser, itemId, count) {
    local InvenObj = SUser.GetInven();
    if (!InvenObj) return;
    if (InvenObj.GetSlotById(itemId) != -1) {
        local slot = InvenObj.GetSlotById(itemId);
        local ItemObj = InvenObj.GetSlot(1, slot);
        local PvfItemObj = PvfItem.GetPvfItemById(itemId);
        if (PvfItemObj) {
            local maxStack = Sq_CallFunc(S_Ptr("0x0822C9FC"), "int", ["pointer"], PvfItemObj.C_Object);
            local currentCount = Sq_CallFunc(S_Ptr("0x80F783A"), "int", ["pointer"], ItemObj.C_Object);
            if (currentCount < maxStack) {
                local canAdd = maxStack - currentCount;
                if (count <= canAdd) {
                    Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, currentCount + count);
                    SUser.SendUpdateItemList(1, 0, slot);
                    return;
                } else {
                    Sq_CallFunc(S_Ptr("0x80CB884"), "int", ["pointer", "int"], ItemObj.C_Object, maxStack);
                    SUser.SendUpdateItemList(1, 0, slot);
                    local remaining = count - canAdd;
                    SUser.ReqDBSendMultiMail("GM", "背包堆叠已满，部分道具已通过邮件发送", 0, [[itemId, remaining]]);
                    return;
                }
            }
        }
    }
    SUser.GiveItem(itemId, count);
}

// ========== 定时回调 ==========

function _Dps_MultiBonus_Tick_() {
    local Config = GlobalConfig.Get("多倍泡点配置.json");
    local OnlineList = World.GetOnlinePlayer();

    local detectItem = Config["挂机配置"]["检测物品ID"].tointeger();
    local areaMap = Config["挂机配置"]["挂机区域"];
    local isCera = Config["挂机配置"]["奖励类型(true点券/false代币)"];
    local ceraMultiplier = Config["挂机配置"]["点券倍率"].tointeger();
    local pointMultiplier = Config["挂机配置"]["代币倍率"].tointeger();
    local baseCera = Config["挂机配置"]["每次基础点券"].tointeger();
    local basePoint = Config["挂机配置"]["每次基础代币"].tointeger();

    local jackpotOn = Config["大奖配置"]["开启大奖(true/false)"];
    local jackpotChance = Config["大奖配置"]["中奖概率(百分比)"].tointeger();
    local jackpotPool = Config["大奖配置"]["大奖奖池"];
    local jackpotAnnouncePos = Config["大奖配置"]["中奖公告位置"].tointeger();
    local jackpotAnnounceMsg = Config["大奖配置"]["中奖公告"];

    local sendPos = Config["信息播报"]["发送位置"].tointeger();
    local icon = Config["信息播报"]["图标"].tointeger();
    local colorRgb = Config["信息播报"]["颜色rgb"];
    local countRgb = Config["信息播报"]["数量颜色rgb"];
    local bonusHint = Config["信息播报"]["泡点获得提示"];
    local jackpotHint = Config["信息播报"]["大奖获得提示"];

    local fakeIp = Config["离线假人IP"];
    local giveFake = Config["是否发放给假人(false不发放/true发放)"];

    foreach (SUser in OnlineList) {
        // 假人IP过滤
        local ip = _Dps_MultiBonus_GetIP_(SUser);
        if (!giveFake && ip == fakeIp) continue;

        // 区域检测
        local loc = SUser.GetLocation();
        if (!loc) continue;
        local town = loc.Town.tostring();
        if (!(town in areaMap)) continue;
        local areaRule = areaMap[town];
        if (areaRule != "all") {
            local areaMatch = false;
            local curArea = loc.Area;
            foreach (a in areaRule) {
                if (a == curArea) { areaMatch = true; break; }
            }
            if (!areaMatch) continue;
        }

        // 物品检测
        if (detectItem > 0) {
            local InvenObj = SUser.GetInven();
            if (!InvenObj || InvenObj.GetSlotById(detectItem) == -1) continue;
        }

        // --- 发放泡点奖励 ---
        local rewardAmount = 0;
        if (isCera) {
            rewardAmount = baseCera * ceraMultiplier;
            if (rewardAmount > 0) SUser.RechargeCera(rewardAmount);
        } else {
            rewardAmount = basePoint * pointMultiplier;
            if (rewardAmount > 0) SUser.RechargeCeraPoint(rewardAmount);
        }

        // 泡点提示
        if (rewardAmount > 0) {
            local msg = _Dps_MultiBonus_Replace_(bonusHint, "{0}", rewardAmount.tostring());
            msg = _Dps_MultiBonus_Replace_(msg, "{1}", isCera ? ceraMultiplier.tostring() : pointMultiplier.tostring());
            local AdObj = AdMsg();
            AdObj.PutType(sendPos);
            if (sendPos != 14) AdObj.PutString(" ");
            AdObj.PutImoticon(icon);
            AdObj.PutColorString(msg, colorRgb);
            AdObj.Finalize();
            SUser.Send(AdObj.MakePack());
            AdObj.Delete();
        }

        // --- 大奖判定 ---
        if (jackpotOn && jackpotPool.len() > 0) {
            if (rand() % 100 < jackpotChance) {
                local idx = _Dps_MultiBonus_Roll_(jackpotPool);
                if (idx >= 0) {
                    local prize = jackpotPool[idx];
                    local prizeId = prize[0].tointeger();
                    local prizeCount = prize[2].tointeger();
                    _Dps_MultiBonus_GiveItem_(SUser, prizeId, prizeCount);

                    // 个人提示
                    local prizeName = PvfItem.GetNameById(prizeId);
                    local selfMsg = _Dps_MultiBonus_Replace_(jackpotHint, "{0}", prizeName);
                    selfMsg = _Dps_MultiBonus_Replace_(selfMsg, "{1}", prizeCount.tostring());
                    SUser.SendNotiPacketMessage(selfMsg, sendPos);

                    // 全服公告
                    local worldMsg = _Dps_MultiBonus_Replace_(jackpotAnnounceMsg, "{0}", SUser.GetCharacName());
                    worldMsg = _Dps_MultiBonus_Replace_(worldMsg, "{1}", prizeName);
                    worldMsg = _Dps_MultiBonus_Replace_(worldMsg, "{2}", prizeCount.tostring());
                    local WorldObj = AdMsg();
                    WorldObj.PutType(jackpotAnnouncePos);
                    WorldObj.PutString(worldMsg);
                    WorldObj.Finalize();
                    World.SendAll(WorldObj.MakePack());
                    WorldObj.Delete();
                }
            }
        }
    }
}

// ========== IP获取 ==========

function _Dps_MultiBonus_GetIP_(SUser) {
    local s_addr = Sq_CallFunc(S_Ptr("0x084EC90A"), "int", ["pointer"], SUser.C_Object);
    if (s_addr) {
        local inet_ntoa = Sq_CallFunc(S_Ptr("0x0807DDC0"), "pointer", ["int"], s_addr);
        return NativePointer(inet_ntoa).readUtf8String();
    }
    return null;
}

// ========== 加载/重载入口 ==========

function _Dps_MultiBonus_Logic_() {
    local Config = GlobalConfig.Get("多倍泡点配置.json");
    local interval = Config["定时配置"]["时间间隔(分钟)"].tointeger();
    local cronExpr = format("0 */%d * * * *", interval);
    Timer.SetCronTask(_Dps_MultiBonus_Tick_, {
        Cron = cronExpr,
        Name = "MultiBonusTask"
    });
}

function _Dps_MultiBonus_Main_() {
    _Dps_MultiBonus_Logic_();
}

function _Dps_MultiBonus_Main_Reload_(OldConfig) {
    Timer.RemoveCronTask("MultiBonusTask");
    _Dps_MultiBonus_Logic_();
}
