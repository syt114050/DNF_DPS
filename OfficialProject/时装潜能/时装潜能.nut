function _Dps_Avatar_hidden_option_Main_() {
    NativePointer(S_Ptr("0x08509D49")).writeByteArray([0xEB]);
    Cb_Inventory_AddAvatarItem_Enter_Func.hidden_option <- function(args) {
        NativePointer(S_Ptr("0x08509D34")).writeUShort(MathClass.Rand(1, 64));
    }
    Cb_Item_IsHiddenOption_Leave_Func.hidden_option <- function(args) {
        return 1;
    }
}