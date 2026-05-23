
function _Dps_DJJQRW_Main_() {

    local Config = GlobalConfig.Get("道具接取任务.json");
	foreach(	  item in      Config["道具对应接取任务"]){

		local a = item[0];
		local b = item[1];
	    Cb_Use_Item_Sp_Func[a] <- function(SUser, ItemId) {
		print(b);
		  Sq_CUser_QuestAction(SUser.C_Object, 33, b, 0, 0);
	    }

	}
	
}
