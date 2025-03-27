
ø
common.protocommon"”
Header
msg_type (	RmsgType
seq (Rseq
version (Rversion
	timestamp (R	timestamp%
client_version (	RclientVersion"9
	ErrorResp
code (	Rcode
message (	Rmessage"…

PlayerInfo
userid (Ruserid
nickname (	Rnickname
level (Rlevel
exp (Rexp
	vip_level (RvipLevelbproto3
°

game.protogamecommon.proto"h
LoginReq&
header (2.common.HeaderRheader
account (	Raccount
password (	Rpassword"U
	LoginResp0

error_resp (2.common.ErrorRespR	errorResp
userid (Ruserid"R
GetPlayerInfoReq&
header (2.common.HeaderRheader
userid (Ruserid"q
GetPlayerInfoResp0

error_resp (2.common.ErrorRespR	errorResp*
player (2.common.PlayerInfoRplayerbproto3