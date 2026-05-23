_NG_QUEST_GRADE_COMMON_UNIQUE <- 5 //普通任务
_NG_QUEST_GRADE_EPIC <- 0 //主线任务
_NG_QUEST_GRADE_ACHIEVEMENT <- 2 //成就任务

// 任务类型与排除列表的映射
_QUEST_EXCLUDE_MAP2 <- {
    [_NG_QUEST_GRADE_COMMON_UNIQUE] = "普通任务需排除任务ID",
    [_NG_QUEST_GRADE_ACHIEVEMENT] = "成就任务需排除任务ID",
    [_NG_QUEST_GRADE_EPIC] = "主线任务需排除任务ID"
}

function clear_all_quest_by_character_level_nangua2(SUser, Date) {

    local Item_id = Date[15].tointeger();

    if (Date[18] != "3") {
        return;
    }


    local Cofig = GlobalConfig.Get("任务相关配置_2.json");
    local poolMapping = {
        [Cofig["主线任务完成券道具ID"]] = _NG_QUEST_GRADE_EPIC,
        [Cofig["普通任务完成券道具ID"]] = _NG_QUEST_GRADE_COMMON_UNIQUE,
        [Cofig["成就任务完成券道具ID"]] = _NG_QUEST_GRADE_ACHIEVEMENT
    };
    // 获取对应的type
    local quest_type = poolMapping[Item_id];
    // 玩家任务信息
    local user_quest = SUser.GetQuest();

    // 玩家已完成任务信息
    local WongWork_CQuestClear = NativePointer(user_quest).add(4);
    // 玩家当前等级
    local charac_lv = SUser.GetCharacLevel();
    // 本次完成任务数量
    local clear_quest_cnt = 0;
    // 获取pvf数据
    local data_manager = Sq_CallFunc(S_Ptr("0x80CC19B"), "pointer");

    // 使用全局排除列表
    local exclude_quset_id = _QUEST_EXCLUDE_MAP2.rawin(quest_type) ? Cofig[_QUEST_EXCLUDE_MAP2[quest_type]] : [];

    //完成当前已接任务
    for (local i = 0; i< 20; i++) {
        // 任务id
        local doing_quest_id = NativePointer(user_quest).add(4 * (i + 7500 + 2)).readInt();

        if (doing_quest_id > 0) {
            // 获取当前任务的数据
            local quest = Sq_CallFunc(S_Ptr("0x835FDC6"), "pointer", ["pointer", "int"], data_manager, doing_quest_id);
            if (quest) {
                // 任务类型
                local quest_grade = NativePointer(quest).add(8).readInt();

                // 判断任务类型并且不在排除列表中
                if (quest_grade == quest_type && exclude_quset_id.find(doing_quest_id) == null) {
                    // 无条件完成任务
                    SUser.ClearQuest_Gm(doing_quest_id);
                }
            }
        }
    }

    // 遍历所有任务ID
    for (local quest_id = 1; quest_id< 30000; quest_id++) {
        // 检查任务是否在排除列表中
        if (exclude_quset_id.find(quest_id) != null) {
            continue;
        }

        // 跳过已完成的任务
        local isCleared = isClearedQuest(WongWork_CQuestClear.C_Object, quest_id);
        if (isCleared) {
            continue;
        }

        // 获取任务数据
        local quest = Sq_CallFunc(S_Ptr("0x835FDC6"), "pointer", ["pointer", "int"], data_manager, quest_id);
        if (quest) {
            // 任务类型
            local quest_grade = NativePointer(quest).add(8).readInt();

            if (quest_grade == quest_type) {
                // 只判断任务最低等级要求 忽略 职业/前置 等任务要求 可一次性完成当前等级所有任务
                local quest_min_lv = NativePointer(quest).add(0x20).readInt();

                if (quest_min_lv <= charac_lv) {
                    Sq_CallFunc(S_Ptr("0x808BA78"), "int", ["pointer", "int"], WongWork_CQuestClear.C_Object, quest_id);

                    // 本次自动完成任务计数
                    clear_quest_cnt++;
                }
            }
        }
    }

    // 通知客户端更新
    if (clear_quest_cnt > 0) {
        local Pack = Packet();
        Sq_CallFunc(S_Ptr("0x868B044"), "int", ["pointer"], SUser.C_Object);
        Sq_CallFunc(S_Ptr("0x86ABBA8"), "int", ["pointer", "pointer"], user_quest, Pack.C_Object);
        SUser.Send(Pack);
        Pack.Delete();
        // 公告通知客户端本次自动完成任务数据
        SUser.SendNotiPacketMessage("已自动完成当前等级任务数量: " + clear_quest_cnt, 8);
    } else {
        SUser.SendNotiPacketMessage("没有可清理的任务", 8);
    }
}

//指定每日任务完成券
function QUEST_ByMRFuncBynangua2(SUser, Date) {

    local ItemId = Date[15].tointeger();

    if (Date[18] != "3") {
        return;
    }
    local Cofig = GlobalConfig.Get("任务相关配置_2.json");
    // 玩家已完成任务信息
    local user_quest = SUser.GetQuest();
    local WongWork_CQuestClear = NativePointer(user_quest).add(4);

    // 是否有任务已被清理
    local anyTaskCleared = false;

    // 遍历并完成每一个任务
    for (local i = 0; i< Cofig["指定完成每日任务ID"].len(); i++) {
        local quest_id = Cofig["指定完成每日任务ID"][i];
        local isCleared = isClearedQuest(WongWork_CQuestClear.C_Object, quest_id);

        if (isCleared) {
            continue;
        } else {
            SUser.ClearQuest_Gm(quest_id);
            anyTaskCleared = true;
        }
    }

    if (anyTaskCleared) {
        SUser.SendNotiPacketMessage("指定每日任务已完成!", 8);
    } else {
        SUser.SendNotiPacketMessage("没有可清理的任务", 8);
    }
}

//指定每日任务重置券
function QUEST_ByCZMRFuncBynangua2(SUser, Date) {
    local ItemId = Date[15].tointeger();

    if (Date[18] != "3") {
        return;
    }
    local Cofig = GlobalConfig.Get("任务相关配置_2.json");
    // 玩家已完成任务信息
    local user_quest = SUser.GetQuest();
    local WongWork_CQuestClear = NativePointer(user_quest).add(4);

    // 是否有任务被重置
    local anyTaskReset = false;

    // 遍历并重置每一个任务
    for (local i = 0; i< Cofig["指定完成每日任务ID"].len(); i++) {
        local quest_id = Cofig["指定完成每日任务ID"][i];
        local isCleared = isClearedQuest(WongWork_CQuestClear.C_Object, quest_id);

        if (!isCleared) {
            continue;
        } else {
            Sq_CallFunc(S_Ptr("0x808BAAC"), "int", ["pointer", "int"], WongWork_CQuestClear.C_Object, quest_id);
            anyTaskReset = true;
        }
    }

    if (anyTaskReset) {
        //通知客户端更新任务列表
        Sq_CallFunc(S_Ptr("0x868B044"), "int", ["pointer"], SUser.C_Object);
        local Pack = Packet();
        Sq_CallFunc(S_Ptr("0x86ABBA8"), "int", ["pointer", "pointer"], user_quest, Pack.C_Object);
        SUser.Send(Pack);
        Pack.Delete();
        SUser.SendNotiPacketMessage("指定每日任务已重置!", 8);
    } else {
        SUser.SendNotiPacketMessage("没有可重置的任务", 8);
    }
}

//重置所有任务为未完成状态
function QUEST_ByALLFuncBynangua2(SUser, Date) {
    local ItemId = Date[15].tointeger();

    if (Date[18] != "3") {
        return;
    }
    local GetState = SUser.GetState()
    local user_quest = SUser.GetQuest();
    local WongWork_CQuestClear = NativePointer(user_quest).add(4);
    //清空已接任务列表
    for (local i = 0; i< 20; i++) {
        NativePointer(user_quest).add(4 * (i + 7500 + 2)).writeInt(0);
    }
    //所有任务设置未完成状态
    for (local i = 0; i< 29999; i++) {
        Sq_CallFunc(S_Ptr("0x808BAAC"), "int", ["pointer", "int"], WongWork_CQuestClear.C_Object, i);
    }
    //通知客户端更新任务列表
    Sq_CallFunc(S_Ptr("0x868B044"), "int", ["pointer"], SUser.C_Object);
    local Pack = Packet();
    Sq_CallFunc(S_Ptr("0x86ABBA8"), "int", ["pointer", "pointer"], user_quest, Pack.C_Object);
    SUser.Send(Pack);
    Pack.Delete();
    SUser.SendNotiPacketMessage("所有任务已重置!", 8);
}

function isClearedQuest(C_Object, questID) {
    return Sq_CallFunc(S_Ptr("0x808BAE0"), "bool", ["pointer", "int"], C_Object, questID);
}

//加载入口
function _Dps_QuestInfo_nangua_Main_2() {
    _Dps_QuestInfo_nangua_Logic_2();
}

//重载入口
function _Dps_QuestInfo_nangua_Main_Reload_2(OldConfig) {

}

function _Dps_QuestInfo_nangua_Logic_2() {
    local Cofig = GlobalConfig.Get("任务相关配置_2.json");
    // 主线任务完成券
    Cb_History_ItemDown_Func["任务完成券"] <- Cb_History_ItemDown_FuncMapRW;
}


function Cb_History_ItemDown_FuncMapRW(SUser, Date) {
    local Cofig = GlobalConfig.Get("任务相关配置_2.json");

    switch (Date[15].tointeger()) {
        case Cofig["主线任务完成券道具ID"]:
            clear_all_quest_by_character_level_nangua2(SUser, Date);
            break;
        case Cofig["普通任务完成券道具ID"]:
            clear_all_quest_by_character_level_nangua2(SUser, Date);
            break;
        case Cofig["成就任务完成券道具ID"]:
            clear_all_quest_by_character_level_nangua2(SUser, Date);
            break;
        case Cofig["指定每日任务完成券道具ID"]:
            QUEST_ByMRFuncBynangua2(SUser, Date);
            break;
        case Cofig["指定每日任务重置券道具ID"]:
            QUEST_ByCZMRFuncBynangua2(SUser, Date);
            break;
        case Cofig["重置所有任务道具ID"]:
            QUEST_ByALLFuncBynangua2(SUser, Date);
            break;
    }
}