package core
import "core:encoding/cbor"
import "core:mem"

PORT :: 27015
MsgHeaderSize :: u8

MsgType :: enum MsgHeaderSize {
	None,
	MsgMoveActor,
	MsgGameState,
}

Msg :: union {
	MsgPlayerInput,
	MsgGameState,
}

MsgPlayerInput :: struct {
	duration_msec : u16,
	input_dir: Vec2,
	looking: Vec3,
}

MsgGameState :: struct {
	state: GameState,
}

@require_results
serialize_msg :: proc(msg: Msg, allocator : mem.Allocator) -> (data: []byte, err: cbor.Marshal_Error) {
	return cbor.marshal(msg, allocator = allocator)
}

@require_results
deserialize_msg :: proc(data: []byte, allocator : mem.Allocator) -> (msg: Msg, err: cbor.Unmarshal_Error) {
	err = cbor.unmarshal(transmute(string)data, &msg, allocator = allocator)
	return
}
