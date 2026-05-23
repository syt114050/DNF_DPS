print(">>>>>>每日签到系统插件开始加载<<<<<<");

class _DailyCheckIn {
    function init() {
        print(">>>>>>每日签到系统插件初始化<<<<<<");

        Gm_InputFunc_Handle["签到"] <- function(SUser, CmdString) {
            _DailyCheckIn.handleCheckIn(SUser);
            return true;
        };

        _DailyCheckIn.initDatabase();
    }

    function initDatabase() {
        print(">>>>>>初始化签到系统数据库表<<<<<<");

        local Config = GlobalConfig.Get("签到系统配置.json");
        local PoolObj = MysqlPool.GetInstance();
        PoolObj.SetBaseConfiguration(Config["数据库配置"]["IP"], Config["数据库配置"]["端口"], Config["数据库配置"]["用户名"], Config["数据库配置"]["密码"]);
        PoolObj.PoolSize = 10;
        PoolObj.Init();

        local SqlObj = MysqlPool.GetInstance().GetConnect();
        local CreateSql = "CREATE TABLE IF NOT EXISTS taiwan_cain_2nd.check_in_records ("
            + "chara_id INT PRIMARY KEY, "
            + "chara_name VARCHAR(50) NOT NULL, "
            + "consecutive_days INT DEFAULT 1, "
            + "last_game_date DATE NOT NULL)";
        SqlObj.Exec_Sql(CreateSql);
        print(">>>>>>创建数据库表完成<<<<<<");

        MysqlPool.GetInstance().PutConnect(SqlObj);
        print(">>>>>>签到系统数据库表初始化完成<<<<<<");
    }

    function handleCheckIn(SUser) {
        local charaId = SUser.GetCID();
        local charaName = SUser.GetCharacName();
        local Config = GlobalConfig.Get("签到系统配置.json");

        local SqlObj = MysqlPool.GetInstance().GetConnect();

        // 查询当前连续天数及距上次签到的游戏日差距（每日6点刷新）
        local SelectSql = "SELECT consecutive_days, "
            + "DATEDIFF(DATE(DATE_SUB(NOW(), INTERVAL 6 HOUR)), last_game_date) AS day_diff "
            + "FROM taiwan_cain_2nd.check_in_records WHERE chara_id=" + charaId;
        local Result = SqlObj.Exec_Sql(SelectSql);

        local newDays = 1;

        if (Result && typeof Result == "table" && Result.size() > 0) {
            local dayDiff = Result[0][1].tointeger();

            if (dayDiff == 0) {
                // 同一游戏日内已签到
                SUser.SendNotiPacketMessage(Config["已签到提示"], 8);
                MysqlPool.GetInstance().PutConnect(SqlObj);
                return;
            } else if (dayDiff == 1) {
                // 连续签到，天数+1
                newDays = Result[0][0].tointeger() + 1;
            }
            // dayDiff > 1: 断签，重置为1
        }

        // 超过循环周期后回到第1天
        local cycleDays = Config.rawin("循环周期") ? Config["循环周期"].tointeger() : 30;
        if (newDays > cycleDays) newDays = 1;

        // 写入/更新签到记录
        local UpsertSql = "INSERT INTO taiwan_cain_2nd.check_in_records "
            + "(chara_id, chara_name, consecutive_days, last_game_date) VALUES ("
            + charaId + ",'" + charaName + "'," + newDays
            + ",DATE(DATE_SUB(NOW(), INTERVAL 6 HOUR))) "
            + "ON DUPLICATE KEY UPDATE consecutive_days=" + newDays
            + ", chara_name='" + charaName
            + "', last_game_date=DATE(DATE_SUB(NOW(), INTERVAL 6 HOUR))";
        SqlObj.Exec_Sql(UpsertSql);
        MysqlPool.GetInstance().PutConnect(SqlObj);

        // 发放每日基础奖励
        if (Config.rawin("每日基础奖励")) {
            foreach (reward in Config["每日基础奖励"]) {
                SUser.GiveItem(reward[0], reward[1]);
            }
        }

        // 发放里程碑奖励
        if (Config.rawin("里程碑奖励")) {
            local Milestones = Config["里程碑奖励"];
            local dayKey = "" + newDays;
            if (Milestones.rawin(dayKey)) {
                foreach (reward in Milestones[dayKey]) {
                    SUser.GiveItem(reward[0], reward[1]);
                }
            }
        }

        // 签到成功提示
        local successMsg = Config.rawin("签到成功提示")
            ? format(Config["签到成功提示"], newDays)
            : format("签到成功！您已连续签到 %d 天！", newDays);
        SUser.SendNotiPacketMessage(successMsg, 8);

        print(">>>>>>玩家签到成功，角色ID: " + charaId + "，连续签到: " + newDays + "天<<<<<<");
    }
}

function _Dps_CheckInSystem_Main_() {
    print(">>>>>>每日签到系统Main函数被调用<<<<<<");
    _DailyCheckIn.init();
}

function _Dps_CheckInSystem_Main_Reload_(OldConfig) {
    print(">>>>>>每日签到系统重载函数被调用<<<<<<");
    _DailyCheckIn.init();
}

print(">>>>>>每日签到系统插件加载完成<<<<<<");
