// 深渊活动状态枚举
local HELLPARTY_STATE_END = 0;    // 活动结束状态
local HELLPARTY_STATE_RUNNING = 1; // 活动进行中状态

// 深渊活动数据
local hellpartyEventInfo = {
    "state": HELLPARTY_STATE_END,   // 当前活动状态
    "start_time": 0,                // 活动开始时间
    "reward_counts": {},            // 每个指定道具的剩余奖励次数
    "last_reminder_minute": -1,     // 上次提醒的分钟数，初始化为-1
    "last_reminder_second": -1,     // 上次提醒的秒数，初始化为-1
    "current_time_slot": null,      // 当前活动时间段配置
    "drop_prevention_enabled": false // 是否启用了禁止丢弃物品
}

// 初始化禁止丢弃物品功能
function Init_Hellparty_Drop_Prevention() {
    // 如果没有创建过这个模拟内存就创建
    if(!getroottable().rawin("_HellpartyEmptyCharacInfo_")) {
        getroottable()._HellpartyEmptyCharacInfo_ <- Memory.alloc(17);
        Memory.reset(getroottable()._HellpartyEmptyCharacInfo_, 17);
    }
    // 如果没有创建过这个跳转Flag就创建并初始化
    if(!getroottable().rawin("_HellpartyDropPreventFlag_")) {
        getroottable()._HellpartyDropPreventFlag_ <- false;
    }
}

// 深渊活动入口点
function _Dps_Start_Hellparty_Event_Main_() {
    _Dps_Start_Hellparty_Event_Logic_();
}

// 深渊活动重载入口点
function _Dps_Start_Hellparty_Event_Main_Reload_(OldConfig) {

    // 移除检查任务
    Timer.RemoveCronTask("HellpartyCheckTask");

    // 移除旧的定时任务
    if (OldConfig && "深渊活动配置" in OldConfig && "活动时间段" in OldConfig["深渊活动配置"]) {
        foreach(timeSlot in OldConfig["深渊活动配置"]["活动时间段"]) {
            local start_time = timeSlot["开启时间"];
            local task_id = format("HellpartyEventTask_%d_%d", start_time[0], start_time[1]);
            Timer.RemoveCronTask(task_id);
        }
    }

    // 设置活动状态为结束（如果当前正在进行）
    if (hellpartyEventInfo.state == HELLPARTY_STATE_RUNNING) {
        hellpartyEventInfo.state = HELLPARTY_STATE_END;
        World.SendNotiPacketMessage("【深渊探险活动】因配置更新已结束", 14);
    }

    // 广播活动时间更改通知
    broadcast_hellparty_time_changes();

    // 重新注册
    _Dps_Start_Hellparty_Event_Logic_();
}

// 深渊活动逻辑入口点
function _Dps_Start_Hellparty_Event_Logic_() {
    local Config = GlobalConfig.Get("深渊活动配置_nangua.json");

    // 检查活动总开关
    if (!Config["深渊活动配置"]["活动总开关(true开启/false关闭)"]) {
        return;
    }

    // 注册禁止丢弃物品的回调函数
    Cb_DropItem_check_error_Enter_Func.HellpartyDropPrevention <- function(args) {
        local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
        // 只在活动进行中、启用了禁止丢弃功能且功能开关打开时才生效
        if (hellpartyEventInfo.state == HELLPARTY_STATE_RUNNING &&
            hellpartyEventInfo.drop_prevention_enabled &&
            Config["深渊活动配置"]["活动期间开启物品禁止丢弃功能(true开启/false关闭)"]) {
            // 确保必要的变量存在
            if(!getroottable().rawin("_HellpartyEmptyCharacInfo_")) {
                getroottable()._HellpartyEmptyCharacInfo_ <- Memory.alloc(17);
                Memory.reset(getroottable()._HellpartyEmptyCharacInfo_, 17);
            }
            if(!getroottable().rawin("_HellpartyDropPreventFlag_")) {
                getroottable()._HellpartyDropPreventFlag_ <- false;
            }

            getroottable()._HellpartyDropPreventFlag_ = true;
            args[1] = getroottable()._HellpartyEmptyCharacInfo_.C_Object;
        }
        return args;
    }

    Cb_DropItem_check_error_Leave_Func.HellpartyDropPrevention <- function(args) {
        local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
        // 只在活动进行中、启用了禁止丢弃功能且功能开关打开时才生效
        if (hellpartyEventInfo.state == HELLPARTY_STATE_RUNNING &&
            hellpartyEventInfo.drop_prevention_enabled &&
            Config["深渊活动配置"]["活动期间开启物品禁止丢弃功能(true开启/false关闭)"]) {
            if(!getroottable().rawin("_HellpartyDropPreventFlag_")) {
                getroottable()._HellpartyDropPreventFlag_ <- false;
                return;
            }

            if(getroottable()._HellpartyDropPreventFlag_) {
                getroottable()._HellpartyDropPreventFlag_ = false;
                return 19;
            }
        }
    }

    local open_days = Config["深渊活动配置"]["每周几开放活动"];
    local current_date = date();
    local current_weekday = current_date.wday;
    if (current_weekday == 0) current_weekday = 7; // 转换为1-7格式

    // 检查今天是否开放
    local is_open_today = false;
    foreach(day in open_days) {
        if (day == current_weekday) {
            is_open_today = true;
            break;
        }
    }

    if (!is_open_today) {
        return;
    }

    // 为每个时间段注册定时任务
    foreach(timeSlot in Config["深渊活动配置"]["活动时间段"]) {
        local start_time = timeSlot["开启时间"];
        local start_hour = start_time[0];
        local start_minute = start_time[1];

        // 使用格式化的唯一任务ID
        local task_id = format("HellpartyEventTask_%d_%d", start_hour, start_minute);

        // 创建配置的本地副本
        local timeSlotCopy = {
            "开启时间": [start_time[0], start_time[1]],
            "持续时间(分钟)": timeSlot["持续时间(分钟)"],
            "指定道具奖励配置": {
                "指定道具ID": []
            }
        };

        // 复制指定道具奖励配置
        foreach(item in timeSlot["指定道具奖励配置"]["指定道具ID"]) {
            local itemCopy = {
                "指定道具": item["指定道具"],
                "奖励次数": item["奖励次数"],
                "奖励列表": []
            };
            foreach(reward in item["奖励列表"]) {
                itemCopy["奖励列表"].append([reward[0], reward[1]]);
            }
            timeSlotCopy["指定道具奖励配置"]["指定道具ID"].append(itemCopy);
        }

        // cron 表达式 (秒 分 时 日 月 周)
        local cronExpression = format("0 %d %d * * *", start_minute, start_hour);

        // 注册定时任务，传入时间段配置的副本
        Timer.SetCronTask(function() {
            On_Start_Hellparty_Event(timeSlotCopy);
        }, {
            Cron = cronExpression,
            Name = task_id
        });

    }

    // 注册回调函数
    Cb_UserHistoryLog_ItemAdd_Enter_Func.Hellparty_EventByNangua <- function(args) {
        // 检查活动是否在进行中
        if (hellpartyEventInfo.state == HELLPARTY_STATE_END) return;

        // 检查活动是否已超时
        if (is_hellparty_event_timeout()) return;

        local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
        local SUser = User(NativePointer(args[0]).readPointer());

        // 使用当前活动时间段配置
        if (!hellpartyEventInfo.current_time_slot) return;
        local specifiedItems = hellpartyEventInfo.current_time_slot["指定道具奖励配置"]["指定道具ID"];

        local InvenObj = SUser.GetInven();
        local ItemObj = Item(args[4]);
        // 拾取原因 4代表在副本拾取
        local type = args[5];
        local PartyObj = SUser.GetParty();
        if (!PartyObj) return;
        local Bfobj = PartyObj.GetBattleField();
        local DgnObj = Bfobj.GetDgn();
        if (!DgnObj) return;
        local Dungeon_Name = DgnObj.GetName();
        if (!ItemObj) return;
        local item_id = ItemObj.GetIndex();

        // 检查是否在副本中拾取了物品
        if (type == 4) {
            // 检查是否是指定道具
            foreach(itemConfig in specifiedItems) {
                if (itemConfig["指定道具"] == item_id) {
                    // 检查该道具的奖励次数是否已用完
                    local item_id_str = item_id.tostring();
                    if (!(item_id_str in hellpartyEventInfo.reward_counts) || hellpartyEventInfo.reward_counts[item_id_str] <= 0) {
                        // 奖励次数已用完
                        local MsgObj = AdMsg();
                        MsgObj.PutType(Config["深渊活动配置"]["信息发送位置"]);
                        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                            MsgObj.PutString(" ");
                        }
                        MsgObj.PutColorString("很遗憾", [255, 130, 0]);
                        MsgObj.PutEquipment(item_id);
                        MsgObj.PutColorString("的奖励次数已达上限", [255, 130, 0]);
                        MsgObj.Finalize();
                        SUser.Send(MsgObj.MakePack());
                        MsgObj.Delete();
                        return;
                    }

                    // 减少奖励次数
                    hellpartyEventInfo.reward_counts[item_id_str]--;
                    local remaining_count = hellpartyEventInfo.reward_counts[item_id_str];

                    // 发送奖励通知
                    local MsgObj = AdMsg();
                    MsgObj.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        MsgObj.PutString(" ");
                    }
                    MsgObj.PutColorString("◆━━━━━━ 深渊探险活动 ━━━━━━◆", [255, 255, 0]);
                    MsgObj.Finalize();
                    World.SendAll(MsgObj.MakePack());
                    MsgObj.Delete();

                    local MsgObj2 = AdMsg();
                    MsgObj2.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        MsgObj2.PutString(" ");
                    }
                    MsgObj2.PutColorString("恭喜 ", [255, 255, 0]);
                    MsgObj2.PutColorString("[" + SUser.GetCharacName() + "]", [255, 20, 0]);
                    MsgObj2.PutColorString(" 获得指定物品：", [255, 255, 0]);
                    MsgObj2.Finalize();
                    World.SendAll(MsgObj2.MakePack());
                    MsgObj2.Delete();

                    local MsgObj3 = AdMsg();
                    MsgObj3.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        MsgObj3.PutString(" ");
                    }
                    MsgObj3.PutColorString("★ ", [255, 20, 0]);
                    MsgObj3.PutEquipment(item_id);
                    MsgObj3.Finalize();
                    World.SendAll(MsgObj3.MakePack());
                    MsgObj3.Delete();

                    // 发送奖励列表头部
                    local rewardHeader = AdMsg();
                    rewardHeader.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        rewardHeader.PutString(" ");
                    }
                    rewardHeader.PutColorString("├ 获得奖励：", [255, 255, 0]);
                    rewardHeader.Finalize();
                    World.SendAll(rewardHeader.MakePack());
                    rewardHeader.Delete();

                    // 收集所有奖励
                    local allRewards = [];
                    foreach(reward in itemConfig["奖励列表"]) {
                        local rewardId = reward[0];
                        local rewardCount = reward[1];

                        // 收集非点券和代币的道具奖励
                        if (rewardId != 0 && rewardId != 1) {
                            allRewards.append([rewardId, rewardCount]);
                        }

                        // 发放点券和代币奖励
                        if (rewardId == 0) {
                            SUser.RechargeCera(rewardCount);
                        } else if (rewardId == 1) {
                            SUser.RechargeCeraPoint(rewardCount);
                        }

                        // 显示奖励信息
                        local rewardMsg = AdMsg();
                        rewardMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
                        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                            rewardMsg.PutString(" ");
                        }
                        rewardMsg.PutColorString("│", [255, 255, 0]);
                        rewardMsg.PutColorString("   ★ ", [0, 191, 255]);

                        if (rewardId == 0) {
                            rewardMsg.PutColorString("[点券]", [0, 191, 255]);
                        } else if (rewardId == 1) {
                            rewardMsg.PutColorString("[代币]", [0, 191, 255]);
                        } else {
                            rewardMsg.PutEquipment(rewardId);
                        }

                        rewardMsg.PutColorString(" x ", [255, 255, 255]);
                        rewardMsg.PutColorString("<" + rewardCount + ">", [255, 20, 0]);
                        rewardMsg.Finalize();
                        World.SendAll(rewardMsg.MakePack());
                        rewardMsg.Delete();
                    }

                    // 一次性发放所有道具奖励
                    if (allRewards.len() > 0) {
                        Nangua_Hellparty.api_CUser_Add_Item_list(SUser, allRewards);
                    }

                    // 显示剩余次数
                    local remainMsg = AdMsg();
                    remainMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        remainMsg.PutString(" ");
                    }
                    remainMsg.PutColorString("└ 剩余次数：", [255, 255, 0]);
                    remainMsg.PutColorString("<" + remaining_count + ">", [255, 20, 0]);
                    remainMsg.PutColorString("次", [255, 255, 0]);
                    remainMsg.Finalize();
                    World.SendAll(remainMsg.MakePack());
                    remainMsg.Delete();

                    // 发送底部分隔线
                    local footerMsg = AdMsg();
                    footerMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        footerMsg.PutString(" ");
                    }
                    footerMsg.PutColorString("◆━━━━━━━━━━━━━━━━━━━◆", [255, 255, 0]);
                    footerMsg.Finalize();
                    World.SendAll(footerMsg.MakePack());
                    footerMsg.Delete();

                    break;
                }
            }
        }
    }

    // 玩家登录时播报此次深渊活动进度及指定道具信息
    Cb_reach_game_world_Func.hellpartyByNangua <-  function(SUser) {
        local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
        //深渊活动更新进度
        if (hellpartyEventInfo.state != HELLPARTY_STATE_END) {
            //通知客户端当前活动状态
            local remain_time = event_hellparty_get_remain_time();
            local minutes_left = (remain_time / 60).tointeger();
            local seconds_left = remain_time % 60;

            // 发送活动剩余时间信息
            local timeMsg = AdMsg();
            timeMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
            if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                timeMsg.PutString(" ");
            }
            timeMsg.PutColorString("◆━━━━  深渊探险活动进行中  ━━━━◆", [255, 255, 0]);
            timeMsg.Finalize();
            SUser.Send(timeMsg.MakePack());
            timeMsg.Delete();

            local timeMsg2 = AdMsg();
            timeMsg2.PutType(Config["深渊活动配置"]["信息发送位置"]);
            if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                timeMsg2.PutString(" ");
            }
            timeMsg2.PutColorString("                 剩余时间: ", [255, 255, 255]);
            if (minutes_left > 0) {
                timeMsg2.PutColorString("<" + minutes_left + ">", [255, 20, 0]);
                timeMsg2.PutColorString("分", [255, 255, 255]);
            }
            if (seconds_left > 0 || minutes_left == 0) {
                timeMsg2.PutColorString("<" + seconds_left + ">", [255, 20, 0]);
                timeMsg2.PutColorString("秒", [255, 255, 255]);
            }
            timeMsg2.Finalize();
            SUser.Send(timeMsg2.MakePack());
            timeMsg2.Delete();

            // 如果启用了禁止丢弃功能，发送提示
            if (Config["深渊活动配置"]["活动期间开启物品禁止丢弃功能(true开启/false关闭)"]) {
                local dropMsg1 = AdMsg();
                dropMsg1.PutType(Config["深渊活动配置"]["信息发送位置"]);
                if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                    dropMsg1.PutString(" ");
                }
                dropMsg1.PutColorString("        特别提示:活动期间", [255, 255, 0]);
                dropMsg1.PutColorString("无法丢弃物品", [255, 20, 0]);
                dropMsg1.Finalize();
                SUser.Send(dropMsg1.MakePack());
                dropMsg1.Delete();
            }

            // 向玩家单独发送指定道具信息
            if (!hellpartyEventInfo.current_time_slot) return;
            local specifiedItems = hellpartyEventInfo.current_time_slot["指定道具奖励配置"]["指定道具ID"];

            // 发送活动道具信息头部
            local headerMsg = AdMsg();
            headerMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
            if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                headerMsg.PutString(" ");
            }
            headerMsg.PutColorString("◆━━━━━ 本次活动指定道具 ━━━━━◆", [255, 255, 0]);
            headerMsg.Finalize();
            SUser.Send(headerMsg.MakePack());
            headerMsg.Delete();

            // 发送每个指定道具的信息
            foreach(itemConfig in specifiedItems) {
                local itemId = itemConfig["指定道具"];
                local itemIdStr = itemId.tostring();
                local remainingCount = itemIdStr in hellpartyEventInfo.reward_counts ? hellpartyEventInfo.reward_counts[itemIdStr] : 0;

                // 显示道具名称
                local itemMsgLine1 = AdMsg();
                itemMsgLine1.PutType(Config["深渊活动配置"]["信息发送位置"]);
                if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                    itemMsgLine1.PutString(" ");
                }
                itemMsgLine1.PutColorString("★ ", [255, 20, 0]);
                itemMsgLine1.PutEquipment(itemId);
                itemMsgLine1.Finalize();
                SUser.Send(itemMsgLine1.MakePack());
                itemMsgLine1.Delete();

                // 显示可获奖励提示
                local rewardHeader = AdMsg();
                rewardHeader.PutType(Config["深渊活动配置"]["信息发送位置"]);
                rewardHeader.PutColorString("├ 可获奖励：", [255, 255, 0]);
                rewardHeader.Finalize();
                SUser.Send(rewardHeader.MakePack());
                rewardHeader.Delete();

                // 显示每个奖励
                foreach(reward in itemConfig["奖励列表"]) {
                    local rewardId = reward[0];
                    local rewardCount = reward[1];

                    local itemMsgLine2 = AdMsg();
                    itemMsgLine2.PutType(Config["深渊活动配置"]["信息发送位置"]);
                    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                        itemMsgLine2.PutString(" ");
                    }
                    itemMsgLine2.PutColorString("│", [255, 255, 0]);
                    itemMsgLine2.PutColorString("   ★ ", [0, 191, 255]);

                    if (rewardId == 0) {
                        itemMsgLine2.PutColorString("[点券]", [0, 191, 255]);
                    } else if (rewardId == 1) {
                        itemMsgLine2.PutColorString("[代币]", [0, 191, 255]);
                    } else {
                        itemMsgLine2.PutEquipment(rewardId);
                    }

                    itemMsgLine2.PutColorString(" x ", [255, 255, 255]);
                    itemMsgLine2.PutColorString("<" + rewardCount + ">", [255, 20, 0]);
                    itemMsgLine2.Finalize();
                    SUser.Send(itemMsgLine2.MakePack());
                    itemMsgLine2.Delete();
                }

                // 显示剩余次数
                local remainMsg = AdMsg();
                remainMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
                if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                    remainMsg.PutString(" ");
                }
                remainMsg.PutColorString("└ 剩余次数：", [255, 255, 0]);
                remainMsg.PutColorString("<" + remainingCount + ">", [255, 20, 0]);
                remainMsg.PutColorString("次", [255, 255, 0]);
                remainMsg.Finalize();
                SUser.Send(remainMsg.MakePack());
                remainMsg.Delete();
            }

            // 发送底部分隔线
            local footerMsg = AdMsg();
            footerMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
            if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                footerMsg.PutString(" ");
            }
            footerMsg.PutColorString("◆━━━━━━━━━━━━━━━━━━━◆", [255, 255, 0]);
            footerMsg.Finalize();
            SUser.Send(footerMsg.MakePack());
            footerMsg.Delete();
        }
    }
}

// 开始深渊活动
function On_Start_Hellparty_Event(timeSlot) {
    // 先确保移除任何已存在的检查任务，避免重复
    Timer.RemoveCronTask("HellpartyCheckTask");

    // 初始化活动状态
    Reset_Hellparty_Info();
    hellpartyEventInfo.current_time_slot = timeSlot;

    local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
    // 启用禁止丢弃物品（根据配置决定）
    if (Config["深渊活动配置"]["活动期间开启物品禁止丢弃功能(true开启/false关闭)"]) {
        if (!hellpartyEventInfo.drop_prevention_enabled) {
            Init_Hellparty_Drop_Prevention();
            hellpartyEventInfo.drop_prevention_enabled = true;
        }
    }

    // 注册定时检查任务(每5秒检查一次)
    Timer.SetCronTask(Event_Hellparty_Timer, {
        Cron = "*/5 * * * * *",  // 每5秒执行一次
        Name = "HellpartyCheckTask"
    });

    // 发送活动开始公告
    local start_time = timeSlot["开启时间"];
    local event_start = AdMsg();
    event_start.PutType(Config["深渊活动配置"]["信息发送位置"]);
    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
        event_start.PutString(" ");
    }
    event_start.PutColorString("◆━━━━━ 深渊探险活动开启 ━━━━━◆", [255, 255, 0]);
    event_start.Finalize();
    World.SendAll(event_start.MakePack());
    event_start.Delete();

    local event_start2 = AdMsg();
    event_start2.PutType(Config["深渊活动配置"]["信息发送位置"]);
    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
        event_start2.PutString(" ");
    }
    event_start2.PutColorString("     活动持续时间：", [255, 255, 0]);
    event_start2.PutColorString("<" + timeSlot["持续时间(分钟)"] + ">", [255, 20, 0]);
    event_start2.PutColorString("分钟", [255, 255, 0]);
    event_start2.PutColorString("   祝各位勇士好运！", [255, 255, 0]);
    event_start2.Finalize();
    World.SendAll(event_start2.MakePack());
    event_start2.Delete();

    // 如果启用了禁止丢弃功能，发送提示
    if (Config["深渊活动配置"]["活动期间开启物品禁止丢弃功能(true开启/false关闭)"]) {
        local dropMsg2 = AdMsg();
        dropMsg2.PutType(Config["深渊活动配置"]["信息发送位置"]);
        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
            dropMsg2.PutString(" ");
        }
        dropMsg2.PutColorString("        特别提示:活动期间", [255, 255, 0]);
        dropMsg2.PutColorString("无法丢弃物品", [255, 20, 0]);
        dropMsg2.Finalize();
        World.SendAll(dropMsg2.MakePack());
        dropMsg2.Delete();
    }

    // 播报本次指定道具信息
    SendSpecifiedItemsInfo();
}

// 播报本次深渊活动指定道具信息
function SendSpecifiedItemsInfo() {
    if (!hellpartyEventInfo.current_time_slot) return;

    local specifiedItems = hellpartyEventInfo.current_time_slot["指定道具奖励配置"]["指定道具ID"];
    local Config = GlobalConfig.Get("深渊活动配置_nangua.json");

    // 发送活动道具信息头部
    local headerMsg = AdMsg();
    headerMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
        headerMsg.PutString(" ");
    }
    headerMsg.PutColorString("◆━━━━━ 本次活动指定道具 ━━━━━◆", [255, 255, 0]);
    headerMsg.Finalize();
    World.SendAll(headerMsg.MakePack());
    headerMsg.Delete();

    // 发送每个指定道具的信息
    foreach(itemConfig in specifiedItems) {
        local itemId = itemConfig["指定道具"];
        local rewardTimes = itemConfig["奖励次数"];

        // 初始化该道具的奖励次数
        hellpartyEventInfo.reward_counts[itemId.tostring()] <- rewardTimes;

        // 显示道具名称
        local itemMsgLine1 = AdMsg();
        itemMsgLine1.PutType(Config["深渊活动配置"]["信息发送位置"]);
        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
            itemMsgLine1.PutString(" ");
        }
        itemMsgLine1.PutColorString("★ ", [255, 20, 0]);
        itemMsgLine1.PutEquipment(itemId);
        itemMsgLine1.Finalize();
        World.SendAll(itemMsgLine1.MakePack());
        itemMsgLine1.Delete();

        // 显示可获奖励提示
        local rewardHeader = AdMsg();
        rewardHeader.PutType(Config["深渊活动配置"]["信息发送位置"]);
        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
            rewardHeader.PutString(" ");
        }
        rewardHeader.PutColorString("├ 可获奖励：", [255, 255, 0]);
        rewardHeader.Finalize();
        World.SendAll(rewardHeader.MakePack());
        rewardHeader.Delete();

        // 显示每个奖励
        foreach(reward in itemConfig["奖励列表"]) {
            local rewardId = reward[0];
            local rewardCount = reward[1];

            local itemMsgLine2 = AdMsg();
            itemMsgLine2.PutType(Config["深渊活动配置"]["信息发送位置"]);
            if(Config["深渊活动配置"]["信息发送位置"] != 14) {
                itemMsgLine2.PutString(" ");
            }
            itemMsgLine2.PutColorString("│", [255, 255, 0]);
            itemMsgLine2.PutColorString("   ★ ", [0, 191, 255]);

            if (rewardId == 0) {
                // 点券奖励
                itemMsgLine2.PutColorString("[点券]", [0, 191, 255]);
            } else if (rewardId == 1) {
                // 代币奖励
                itemMsgLine2.PutColorString("[代币]", [0, 191, 255]);
            } else {
                // 普通道具奖励
                itemMsgLine2.PutEquipment(rewardId);
            }

            itemMsgLine2.PutColorString(" x ", [255, 255, 255]);
            itemMsgLine2.PutColorString("<" + rewardCount + ">", [255, 20, 0]);
            itemMsgLine2.Finalize();
            World.SendAll(itemMsgLine2.MakePack());
            itemMsgLine2.Delete();
        }

        // 显示剩余次数
        local remainMsg = AdMsg();
        remainMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
        if(Config["深渊活动配置"]["信息发送位置"] != 14) {
            remainMsg.PutString(" ");
        }
        remainMsg.PutColorString("└ 剩余次数：", [255, 255, 0]);
        remainMsg.PutColorString("<" + rewardTimes + ">", [255, 20, 0]);
        remainMsg.PutColorString("次", [255, 255, 0]);
        remainMsg.Finalize();
        World.SendAll(remainMsg.MakePack());
        remainMsg.Delete();
    }

    // 发送底部分隔线
    local footerMsg = AdMsg();
    footerMsg.PutType(Config["深渊活动配置"]["信息发送位置"]);
    if(Config["深渊活动配置"]["信息发送位置"] != 14) {
        footerMsg.PutString(" ");
    }
    footerMsg.PutColorString("◆━━━━━━━━━━━━━━━━━━━◆", [255, 255, 0]);
    footerMsg.Finalize();
    World.SendAll(footerMsg.MakePack());
    footerMsg.Delete();
}

// 重置深渊活动信息
function Reset_Hellparty_Info() {
    hellpartyEventInfo.state = HELLPARTY_STATE_RUNNING;
    hellpartyEventInfo.start_time = time();
    hellpartyEventInfo.reward_counts = {}; // 清空奖励次数记录
    hellpartyEventInfo.last_reminder_minute = -1; // 重置上次提醒的分钟数
    hellpartyEventInfo.last_reminder_second = -1; // 重置上次提醒的秒数
    print(">>>>>>>>>>>>>>深渊活动数据已初始化<<<<<<<<<<<<<<");
}

// 深渊活动定时器检查
function Event_Hellparty_Timer() {
    if (hellpartyEventInfo.state == HELLPARTY_STATE_END)
        return;

    // 检查活动是否结束
    if (is_hellparty_event_timeout()) {
        // 活动结束
        on_end_event_hellparty();
        return;
    }

    // 发送活动剩余时间提醒
    local remain_time = event_hellparty_get_remain_time();
    local minutes_left = (remain_time / 60).tointeger();
    local seconds_left = remain_time % 60;

    // 使用秒数范围来判断提醒时机，确保更精确
    if (remain_time <= 65 && remain_time > 60 && hellpartyEventInfo.last_reminder_minute != 1) {
        // 即将进入最后一分钟
        World.SendNotiPacketMessage("【深渊探险活动】还剩最后<1>分钟结束！", 14);
        hellpartyEventInfo.last_reminder_minute = 1;
    } else if (remain_time <= 305 && remain_time > 300 && hellpartyEventInfo.last_reminder_minute != 5) {
        // 即将进入最后五分钟
        World.SendNotiPacketMessage("【深渊探险活动】还剩<5>分钟结束！", 14);
        hellpartyEventInfo.last_reminder_minute = 5;
    } else if (remain_time <= 245 && remain_time > 240 && hellpartyEventInfo.last_reminder_minute != 4) {
        // 即将进入最后四分钟
        World.SendNotiPacketMessage("【深渊探险活动】还剩<4>分钟结束！", 14);
        hellpartyEventInfo.last_reminder_minute = 4;
    } else if (remain_time <= 185 && remain_time > 180 && hellpartyEventInfo.last_reminder_minute != 3) {
        // 即将进入最后三分钟
        World.SendNotiPacketMessage("【深渊探险活动】还剩<3>分钟结束！", 14);
        hellpartyEventInfo.last_reminder_minute = 3;
    } else if (remain_time <= 125 && remain_time > 120 && hellpartyEventInfo.last_reminder_minute != 2) {
        // 即将进入最后两分钟
        World.SendNotiPacketMessage("【深渊探险活动】还剩<2>分钟结束！", 14);
        hellpartyEventInfo.last_reminder_minute = 2;
    }

    // 最后30秒倒计时，每10秒提醒一次
    if (minutes_left == 0 && seconds_left <= 30 && seconds_left > 0) {
        if (seconds_left % 10 == 0 && hellpartyEventInfo.last_reminder_second != seconds_left) {
            World.SendNotiPacketMessage("【深渊探险活动】还剩<" + seconds_left + ">秒结束！", 14);
            hellpartyEventInfo.last_reminder_second = seconds_left;
        }
    }
}

// 检查活动是否已超时
function is_hellparty_event_timeout() {
    if (!hellpartyEventInfo.current_time_slot) return true;
    return event_hellparty_get_remain_time() <= 0;
}

// 计算活动剩余时间(秒)
function event_hellparty_get_remain_time() {
    if (!hellpartyEventInfo.current_time_slot) return 0;
    local cur_time = time();
    local duration_seconds = hellpartyEventInfo.current_time_slot["持续时间(分钟)"] * 60;
    local event_end_time = hellpartyEventInfo.start_time + duration_seconds;
    local remain_time = event_end_time - cur_time;
    return remain_time;
}

// 结束深渊活动
function on_end_event_hellparty() {
    if (hellpartyEventInfo.state == HELLPARTY_STATE_END)
        return;

    // 设置活动状态为结束
    hellpartyEventInfo.state = HELLPARTY_STATE_END;

    // 关闭禁止丢弃物品
    if (hellpartyEventInfo.drop_prevention_enabled) {
        // 重置丢弃物品的Hook标志
        if (getroottable().rawin("_HellpartyDropPreventFlag_")) {
            getroottable()._HellpartyDropPreventFlag_ = false;
        }
        hellpartyEventInfo.drop_prevention_enabled = false;
    }

    // 移除定时检查任务
    Timer.RemoveCronTask("HellpartyCheckTask");

    // 发送活动结束公告
    World.SendNotiPacketMessage("【深渊探险活动】已结束， 感谢各位勇士的参与！", 14);

    // 获取下一个活动时间
    local Config = GlobalConfig.Get("深渊活动配置_nangua.json");

    local current_time = date();
    local current_hour = current_time.hour;
    local current_minute = current_time.min;

    // 获取当前是周几
    local current_date = date();
    local current_weekday = current_date.wday;
    if (current_weekday == 0) current_weekday = 7; // 转换为1-7格式

    // 获取开放日期配置
    local open_days = Config["深渊活动配置"]["每周几开放活动"];
    local time_slots = Config["深渊活动配置"]["活动时间段"];

    // 将时间段按时间排序
    local sorted_time_slots = [];
    foreach(slot in time_slots) {
        sorted_time_slots.append(slot);
    }
    // 按时间排序（冒泡排序）
    for(local i = 0; i < sorted_time_slots.len() - 1; i++) {
        for(local j = 0; j < sorted_time_slots.len() - 1 - i; j++) {
            local time1 = sorted_time_slots[j]["开启时间"];
            local time2 = sorted_time_slots[j + 1]["开启时间"];
            if(time1[0] > time2[0] || (time1[0] == time2[0] && time1[1] > time2[1])) {
                local temp = sorted_time_slots[j];
                sorted_time_slots[j] = sorted_time_slots[j + 1];
                sorted_time_slots[j + 1] = temp;
            }
        }
    }

    // 查找下一个活动时间
    local next_time_slot = null;
    local next_day = null;

    // 先尝试找今天剩余的时间段
    foreach(timeSlot in sorted_time_slots) {
        local start_time = timeSlot["开启时间"];
        local start_hour = start_time[0];
        local start_minute = start_time[1];

        // 如果找到未来的时间点，就使用它
        if ((start_hour > current_hour) || (start_hour == current_hour && start_minute > current_minute)) {
            next_time_slot = timeSlot;
            next_day = current_weekday;
            break;
        }
    }

    // 如果没找到今天剩余的时间段，查找下一个开放日
    if (!next_time_slot) {
        // 查找下一个开放日
        for (local i = 1; i <= 7; i++) {
            local check_day = (current_weekday + i) % 7;
            if (check_day == 0) check_day = 7;

            foreach(open_day in open_days) {
                if (open_day == check_day) {
                    next_day = check_day;
                    next_time_slot = sorted_time_slots[0]; // 使用排序后的第一个时间段
                    break;
                }
            }
            if (next_time_slot) break;
        }
    }

    // 如果找到下一个活动时间，发送通知
    if (next_time_slot) {
        local start_time = next_time_slot["开启时间"];
        local day_names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
        local day_text = "";

        if (next_day == current_weekday) {
            day_text = "今天";
        } else if (next_day > current_weekday) {
            day_text = "本周" + day_names[next_day - 1];
        } else {
            day_text = "下" + day_names[next_day - 1];
        }

        World.SendNotiPacketMessage(format("【深渊探险活动】下次活动时间为%s [%d:%02d]，敬请期待！", day_text, start_time[0], start_time[1]), 14);
    }

    print(">>>>>>>>>>>>>>深渊活动已结束<<<<<<<<<<<<<<");
}

// 广播活动时间更改通知
function broadcast_hellparty_time_changes() {
    local Config = GlobalConfig.Get("深渊活动配置_nangua.json");
    local time_slots = Config["深渊活动配置"]["活动时间段"];

    // 将时间段按时间排序
    local sorted_time_slots = [];
    foreach(slot in time_slots) {
        sorted_time_slots.append(slot);
    }
    // 按时间排序
    for(local i = 0; i < sorted_time_slots.len() - 1; i++) {
        for(local j = 0; j < sorted_time_slots.len() - 1 - i; j++) {
            local time1 = sorted_time_slots[j]["开启时间"];
            local time2 = sorted_time_slots[j + 1]["开启时间"];
            if(time1[0] > time2[0] || (time1[0] == time2[0] && time1[1] > time2[1])) {
                local temp = sorted_time_slots[j];
                sorted_time_slots[j] = sorted_time_slots[j + 1];
                sorted_time_slots[j + 1] = temp;
            }
        }
    }

    // 获取开放日期
    local open_days = Config["深渊活动配置"]["每周几开放活动"];
    local day_names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
    local open_days_text = "";

    foreach(idx, day in open_days) {
        open_days_text += day_names[day - 1];
        if (idx < open_days.len() - 1) {
            open_days_text += "、";
        }
    }

    // 发送开放日期通知
    World.SendNotiPacketMessage("【深渊探险活动】开放日期为: " + open_days_text, 14);

    // 发送时间段通知
    local time_text = "";
    foreach(idx, slot in sorted_time_slots) {
        local start_time = slot["开启时间"];
        time_text += format("%02d:%02d", start_time[0], start_time[1]);
        if (idx < sorted_time_slots.len() - 1) {
            time_text += "、";
        }
    }

    World.SendNotiPacketMessage("【深渊探险活动】开放时间为: " + time_text + "，敬请期待！", 14);
}

class Nangua_Hellparty {
    function checkInventorySlot(SUser, itemid) {
		local InvenObj = SUser.GetInven();
		local type = Sq_CallFunc(S_Ptr("0x085018D2"), "int", ["pointer", "int"], InvenObj.C_Object, itemid);
		local cnt = Sq_CallFunc(S_Ptr("0x08504F64"), "int", ["pointer", "int", "int"], InvenObj.C_Object, type, 1);

		return cnt;
	}
	function api_CUser_Add_Item_list(SUser, item_list) {
		for (local i = 0; i < item_list.len(); i++) {
			local item_id = item_list[i][0]; // 道具代码
			local quantity = item_list[i][1]; // 道具数量
			local cnt = Nangua_Hellparty.checkInventorySlot(SUser, item_id);
			if (cnt == 1) {
				SUser.GiveItem(item_id, quantity); //使用窗口发送奖励
			} else {
				local RewardItems = [];
				RewardItems.append([item_id, quantity]);
				local title = "GM"
				local Text = "由于背包空间不足，已通过邮件发送，请查收！"
				//角色类 发送邮件函数  (标题, 正文, 金币, 道具列表[[3037,100],[3038,100]])
				SUser.ReqDBSendMultiMail(title, Text, 0, RewardItems)
			}
		}
		Nangua_Hellparty.SendItemWindowNotification(SUser, item_list);
	}
	function SendItemWindowNotification(SUser, item_list) {
		local Pack = Packet();
		Pack.Put_Header(1, 163); //协议
		Pack.Put_Byte(1); //默认1
		Pack.Put_Short(0); //槽位id 填入0即可
		Pack.Put_Int(0); //未知 0以上即可
		Pack.Put_Short(item_list.len()); //道具组数
		//写入道具代码和道具数量
		for (local i = 0; i < item_list.len(); i++) {
			Pack.Put_Int(item_list[i][0]); //道具代码
			Pack.Put_Int(item_list[i][1]); //道具数量 装备/时装时 任意均可
		}
		Pack.Finalize(true); //确定发包内容
		SUser.Send(Pack); //发包
		Pack.Delete(); //清空buff区
	}
}