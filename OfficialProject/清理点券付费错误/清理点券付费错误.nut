//清理付费错误
function CleanUpBillingErrors() {
    local Config = GlobalConfig.Get("清理付费错误.json");
    local PoolObj = MysqlPool.GetInstance();
    local Ip = Config["数据库IP 不是外置数据库不要更改"];
    local Port = Config["数据库端口 不懂不要更改"];
    local DbName = Config["数据库用户名 本地用户名不懂不要更改"];
    local Password = Config["数据库密码 本地密码不懂不要更改"];
    //设置数据库连接信息
    PoolObj.SetBaseConfiguration(Ip, Port, DbName, Password);
    //连接池大小
    PoolObj.PoolSize = 10;
	local CheckSql = "UPDATE taiwan_billing.cash_cera SET cera_cold = 0";
	//从池子拿连接
	local SqlObj = MysqlPool.GetInstance().GetConnect();
	local Ret = SqlObj.Select(CheckSql, ["int"]);
	//把连接还池子
	MysqlPool.GetInstance().PutConnect(SqlObj);
	World.SendNotiPacketMessage("玩家付费错误已解决！", 16);
};

// 入口点
function _Dps_CleanUpBillingErrors_Main_() {
    _Dps_CleanUpBillingErrors_Logic_();
}


// 逻辑入口点
function _Dps_CleanUpBillingErrors_Logic_() {
    // 从配置中读取开启时间
    local Config = GlobalConfig.Get("清理付费错误.json");
    local hour = Config["清理付费错误配置"]["开启小时(24小时制)"];
    local minute = Config["清理付费错误配置"]["开启分钟"];
    
    // cron 表达式 (秒 分 时 日 月 周)
    local cronExpression = format("0 %d %d * * *", minute, hour);
    
    // 注册定时任务
    Timer.SetCronTask(CleanUpBillingErrors, {
        Cron = cronExpression,
        Name = "CleanUpBillingErrors"
    });
}