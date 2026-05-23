print(">>>>>>转生系统插件开始加载<<<<<<");

function _Dps_RebirthSystem_Logic_()
{
	local Config = GlobalConfig.Get("转生系统配置.json");
	print(">>>>>>转生系统插件逻辑注册，道具ID: " + Config["转生素材道具ID"] + "<<<<<<");
	Cb_Use_Item_Sp_Func[Config["转生素材道具ID"]] <- function (SUser, ItemId) {
		print(">>>>>>转生系统插件被触发，道具ID: " + ItemId + "<<<<<<");
		if (ItemId != Config["转生素材道具ID"])
		{
			print(">>>>>>道具ID不匹配，当前: " + ItemId + "，期望: " + Config["转生素材道具ID"] + "<<<<<<");
			return;
		}
		local charaId = SUser.GetCID();
		local charaName = SUser.GetCharacName();
		print(">>>>>>角色信息，ID: " + charaId + "，名称: " + charaName + "<<<<<<");
		if (!_RebirthSystem.checkRebirthCondition(SUser))
		{
			print(">>>>>>角色未达到转生条件<<<<<<");
			SUser.SendNotiPacketMessage(Config["未达到条件提示"], 8);
			SUser.GiveItem(ItemId, 1);
			return;
		}
		local rebirthIdentity = _RebirthSystem.selectIdentityByProbability();
		print(">>>>>>选择的转生身份ID: " + rebirthIdentity + "<<<<<<");
		_RebirthSystem.executeRebirth(SUser, charaId, charaName, rebirthIdentity);
	};
}

class _RebirthSystem
{
	function selectIdentityByProbability()
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		local identityList = Config["转生身份配置"];
		local totalWeight = 0;
		foreach (identity in identityList)
		{
			totalWeight += identity["概率权重"];
		}
		print(">>>>>>总权重: " + totalWeight + "<<<<<<");
		local randomValue = rand() % totalWeight;
		print(">>>>>>随机数: " + randomValue + "<<<<<<");
		local currentWeight = 0;
		foreach (identity in identityList)
		{
			currentWeight += identity["概率权重"];
			print(">>>>>>检查身份: " + identity["身份名称"] + "，当前累计权重: " + currentWeight + "<<<<<<");
			if (randomValue < currentWeight)
			{
				print(">>>>>>选中身份: " + identity["身份名称"] + "<<<<<<");
				return identity["身份ID"];
			}
		}
		print(">>>>>>未选中任何身份，返回默认身份<<<<<<");
		return identityList[0]["身份ID"];
	}
	function checkRebirthCondition(SUser)
	{
		print(">>>>>>检查转生条件<<<<<<");
		return true;
	}
	function executeRebirth(SUser, charaId, charaName, rebirthIdentity)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		print(">>>>>>开始执行转生，角色ID: " + charaId + "，身份ID: " + rebirthIdentity + "<<<<<<");
		_RebirthSystem.clearAllItems(SUser);
		print(">>>>>>物品清理完成<<<<<<");
		_RebirthSystem.showRebirthSuccessMessage(SUser, rebirthIdentity);
		print(">>>>>>成功提示已发送<<<<<<");
		// 发送全服播报
		_RebirthSystem.sendRebirthAnnouncement(SUser, rebirthIdentity);
		print(">>>>>>全服播报已发送<<<<<<");
		Timer.SetTimeOut(function ()
		{
			print(">>>>>>10秒倒计时结束，强制下线<<<<<<");
			_RebirthSystem.returnToCharacterSelect(SUser);
		}, 10000);
		print(">>>>>>10秒倒计时已设置<<<<<<");
		_RebirthSystem.sendRebirthRewards(SUser, rebirthIdentity);
		print(">>>>>>奖励邮件已发送<<<<<<");
	}
	function sendRebirthAnnouncement(SUser, rebirthIdentity)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		local identityConfig = null;
		foreach (identity in Config["转生身份配置"])
		{
			if (identity["身份ID"] == rebirthIdentity)
			{
				identityConfig = identity;
				break;
			}
		}
		if (identityConfig)
		{
			local charaName = SUser.GetCharacName();
			local identityName = identityConfig["身份名称"];
			// 创建AdMsg对象
			local AnnouncementObj = AdMsg();
			AnnouncementObj.PutType(14); // 14=顶部公告
			// 添加彩色文字
			AnnouncementObj.PutColorString("恭喜玩家", [255, 255, 0]);
			AnnouncementObj.PutColorString("[" + charaName + "]", [255, 0, 0]);
			AnnouncementObj.PutColorString("转生成为", [255, 255, 0]);
			AnnouncementObj.PutColorString("[" + identityName + "]", [0, 255, 0]);
			AnnouncementObj.PutColorString("，祝您游戏愉快", [255, 255, 0]);
			// 完成构建并发送
			AnnouncementObj.Finalize();
			World.SendAll(AnnouncementObj.MakePack());
			AnnouncementObj.Delete();
			print(">>>>>>发送全服播报: 恭喜玩家[" + charaName + "]转生成为[" + identityName + "]<<<<<<");
		}
	}
	function clearAllItems(SUser)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		local Switches = Config["物品清理开关"];
		print(">>>>>>开始清理物品<<<<<<");
		local InvenObj = SUser.GetInven();
		if (InvenObj)
		{
			print(">>>>>>获取背包对象成功<<<<<<");
			// 清理已穿戴的装备 (INVENTORY_TYPE_BODY = 0)
			if (Switches["清理已穿戴装备"]) {
				for (local i = 0; i < 27; i++)
				{
					local ItemObj = InvenObj.GetSlot(0, i);
					if (ItemObj && !ItemObj.IsEmpty)
					{
						ItemObj.Delete();
						SUser.SendUpdateItemList(0, 0, i);
						print(">>>>>>已删除已穿戴装备，位置: " + i + "<<<<<<");
					}
				}
			}
			// 清理物品栏 (INVENTORY_TYPE_ITEM = 1)
			if (Switches["清理物品栏"]) {
				for (local i = 0; i < 152; i++)
				{
					local ItemObj = InvenObj.GetSlot(1, i);
					if (ItemObj && !ItemObj.IsEmpty)
					{
						ItemObj.Delete();
						SUser.SendUpdateItemList(1, 0, i);
						print(">>>>>>已删除物品栏物品，位置: " + i + "<<<<<<");
					}
				}
			}
			// 清理金库 (INVENTORY_TYPE_WAREHOUSE = 4)
			if (Switches["清理金库"]) {
				local CargoObj = Sq_CallFunc(S_Ptr("0x08151a94"), "pointer", ["pointer"], SUser.C_Object);
				if (CargoObj)
				{
					Sq_CallFunc(S_Ptr("0x0850b0c2"), "void", ["pointer"], CargoObj);
					SUser.SendItemSpace(2);
					print(">>>>>>清理金库完成<<<<<<");
				}
				else
				{
					print(">>>>>>金库对象获取失败<<<<<<");
				}
			}
			// 清理宠物装备栏 (INVENTORY_TYPE_CREATURE = 3)
			if (Switches["清理宠物装备栏"]) {
				for (local i = 0; i < 242; i++)
				{
					local ItemObj = InvenObj.GetSlot(3, i);
					if (ItemObj && !ItemObj.IsEmpty)
					{
						_RebirthSystem.deleteCreature(InvenObj, ItemObj);
						ItemObj.Delete();
						SUser.SendUpdateItemList(3, 0, i);
						print(">>>>>>已删除宠物装备栏物品，位置: " + i + "<<<<<<");
					}
				}
			}
		}
		else
		{
			print(">>>>>>获取背包对象失败<<<<<<");
		}
		if (Switches["清理时装栏"]) _RebirthSystem.clearFashion(SUser);
		if (Switches["清理宠物"]) _RebirthSystem.clearPetsDatabase(SUser);
		if (Switches["清理邮件"]) _RebirthSystem.clearMails(SUser);
	}
	function clearFashion(SUser)
	{
		print(">>>>>>开始清理时装<<<<<<");
		local charaId = SUser.GetCID();
		local InvenObj = SUser.GetInven();
		if (InvenObj)
		{
			// 清理时装栏 (INVENTORY_TYPE_AVARTAR = 2)
			for (local i = 0; i < 105; i++)
			{
				local ItemObj = InvenObj.GetSlot(2, i);
				if (ItemObj && !ItemObj.IsEmpty)
				{
					ItemObj.Delete();
					SUser.SendUpdateItemList(2, 0, i);
					print(">>>>>>已删除时装栏物品，位置: " + i + "<<<<<<");
				}
			}
			// 清理数据库中的时装记录
			local SqlObj = MysqlPool.GetInstance().GetConnect();
			// 删除时装记录 (slot 10-23 对应时装)
			local sql = "DELETE FROM taiwan_cain_2nd.user_items WHERE charac_no = " + charaId + " AND slot >= 10 AND slot <= 23";
			SqlObj.Exec_Sql(sql);
			MysqlPool.GetInstance().PutConnect(SqlObj);
			// 刷新时装空间
			SUser.SendItemSpace(1);
		}
		print(">>>>>>清理时装完成<<<<<<");
	}
	function clearPetsDatabase(SUser)
	{
		print(">>>>>>开始清理宠物数据库记录<<<<<<");
		local charaId = SUser.GetCID();
		local SqlObj = MysqlPool.GetInstance().GetConnect();
		local sql = "DELETE FROM taiwan_cain_2nd.creature_items WHERE charac_no = " + charaId;
		SqlObj.Exec_Sql(sql);
		MysqlPool.GetInstance().PutConnect(SqlObj);
		// 刷新宠物空间
		SUser.SendItemSpace(7);
		print(">>>>>>清理宠物数据库记录完成<<<<<<");
	}
	function deleteCreature(InvenObj, ItemObj)
	{
		// 调用删除宠物的原生函数
		local creatureMgrPtr = Sq_CallFunc(S_Ptr("0x080dd568"), "pointer", ["pointer"], InvenObj.C_Object);
		if (!creatureMgrPtr) return;
		local creature_UID = NativePointer(ItemObj.C_Object).add(7).readU32();
		if (creature_UID == 0) return;
		Sq_CallFunc(S_Ptr("0x0833A854"), "int", ["pointer", "int"], creatureMgrPtr, creature_UID);
	}
	function clearMails(SUser)
	{
		local charaId = SUser.GetCID();
		print(">>>>>>开始清理邮件，角色ID: " + charaId + "<<<<<<");
		local SqlObj = MysqlPool.GetInstance().GetConnect();
		local sql = "DELETE FROM taiwan_cain_2nd.letter WHERE charac_no = " + charaId;
		SqlObj.Exec_Sql(sql);
		sql = "DELETE FROM taiwan_cain_2nd.postal WHERE receive_charac_no = " + charaId;
		SqlObj.Exec_Sql(sql);
		MysqlPool.GetInstance().PutConnect(SqlObj);
		print(">>>>>>邮件清理完成<<<<<<");
	}
	function showRebirthSuccessMessage(SUser, rebirthIdentity)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		local identityConfig = null;
		foreach (identity in Config["转生身份配置"])
		{
			if (identity["身份ID"] == rebirthIdentity)
			{
				identityConfig = identity;
				break;
			}
		}
		if (identityConfig)
		{
			local message = "转生成功！您获得了【" + identityConfig["身份名称"] + "】身份。\n";
			if (identityConfig["介绍"])
			{
				message += identityConfig["介绍"] + "\n";
			}
			message += Config["转生成功提示"];
			print(">>>>>>发送弹窗: " + message + "<<<<<<");
			SUser.SendNotiBox(message, 1);
		}
		else
		{
			print(">>>>>>发送弹窗: " + Config["转生成功提示"] + "<<<<<<");
			SUser.SendNotiBox(Config["转生成功提示"], 1);
		}
	}
	function returnToCharacterSelect(SUser)
	{
		local State = Sq_CallFunc(S_Ptr("0x080da38c"), "int", ["pointer"], SUser.C_Object);
		if (State <= 2)
		{
			print(">>>>>>已在角色选择界面，跳过强制返回<<<<<<");
			return;
		}
		print(">>>>>>1秒后返回角色选择界面<<<<<<");
		Timer.SetTimeOut(function() {
			local State = Sq_CallFunc(S_Ptr("0x080da38c"), "int", ["pointer"], SUser.C_Object);
			if (State > 2)
			{
				Sq_CallFunc(S_Ptr("0x08686fee"), "void", ["pointer", "bool"], SUser.C_Object, true);
				Sq_CallFunc(S_Ptr("0x08651740"), "void", ["pointer"], SUser.C_Object);
			}
		}, 1);
	}
	function sendRebirthRewards(SUser, rebirthIdentity)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		local identityConfig = null;
		foreach (identity in Config["转生身份配置"])
		{
			if (identity["身份ID"] == rebirthIdentity)
			{
				identityConfig = identity;
				break;
			}
		}
		if (!identityConfig)
		{
			print(">>>>>>未找到身份配置，身份ID: " + rebirthIdentity + "<<<<<<");
			return;
		}
		print(">>>>>>开始构建奖励列表，身份名称: " + identityConfig["身份名称"] + "<<<<<<");
		local RewardItems = [];
		foreach (reward in identityConfig["奖励"])
		{
			RewardItems.append([reward[0], reward[1]]);
			print(">>>>>>奖励道具: " + reward[0] + "，数量: " + reward[1] + "<<<<<<");
		}
		local title = Config["奖励邮件标题"];
		local text = Config["奖励邮件内容"] + "\n您获得了【" + identityConfig["身份名称"] + "】身份的专属奖励。";
		print(">>>>>>发送邮件，标题: " + title + "<<<<<<");
		// 使用 SUser.SendMail 发送邮件
		local RewardItemsTable = {};
		foreach (reward in RewardItems)
		{
			RewardItemsTable.rawset(reward[0], reward[1]);
		}
		SUser.SendMail(RewardItemsTable,
		{
			Title = title,
			Text = text
		});
		print(">>>>>>邮件发送完成<<<<<<");
		_RebirthSystem.sendAdditionalRewards(SUser);
	}
	function sendAdditionalRewards(SUser)
	{
		local Config = GlobalConfig.Get("转生系统配置.json");
		if (!Config.rawin("额外奖励")) return;
		local extraConfig = Config["额外奖励"];
		print(">>>>>>开始发送额外奖励邮件<<<<<<");
		local rewardItems = extraConfig["奖励"];
		local rewardTitle = extraConfig["标题"];
		local rewardText = extraConfig["内容"];
		print(">>>>>>发送额外邮件，标题: " + rewardTitle + "<<<<<<");
		local RewardTable = {};
		foreach (item in rewardItems)
		{
			RewardTable.rawset(item[0], item[1]);
			print(">>>>>>额外奖励物品: 物品ID " + item[0] + "，数量 " + item[1] + "<<<<<<");
		}
		SUser.SendMail(RewardTable,
		{
			Title = rewardTitle,
			Text = rewardText
		});
		print(">>>>>>额外奖励邮件发送完成<<<<<<");
	}
}

function _Dps_RebirthSystem_Main_()
{
	print(">>>>>>转生系统插件Main函数被调用<<<<<<");
	_Dps_RebirthSystem_Logic_();
}

function _Dps_RebirthSystem_Main_Reload_(OldConfig)
{
	print(">>>>>>转生系统插件重载函数被调用<<<<<<");
	Cb_Use_Item_Sp_Func.rawdelete(OldConfig["转生素材道具ID"].tointeger());
	_Dps_RebirthSystem_Logic_();
}

print(">>>>>>转生系统插件加载完成<<<<<<");
