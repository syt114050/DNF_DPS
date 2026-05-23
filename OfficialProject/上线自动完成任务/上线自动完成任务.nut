function _Dps_AutomaticallyCompleteTasksOnline_Main_() {
    Cb_History_MileageSet_Func["_DPS_上线自动完成任务_"] <- function(SUser, Data) {
        local Config = GlobalConfig.Get("上线自动完成任务_Lenheart.json");
        local QuestArr = Config["需要完成的任务编号"];
        foreach(QuestId in QuestArr) {
            SUser.ClearQuest_Gm(QuestId);
        }
    }
}