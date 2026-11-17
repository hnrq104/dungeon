package server
import steam "../../ext/steamworks"
import "core:time"
import "../core"
import "core:fmt"

S : ^Server
SERVER_TICK_RATE :: 20 // Hz
SERVER_TICK_PERIOD : time.Duration : 1000*time.Millisecond/SERVER_TICK_RATE // ms

Server :: struct {
	game_state : core.GameState,
	connections : map[steam.HSteamNetConnection]Connection,
	network_tick : time.Time,
	poll_group : steam.HSteamNetPollGroup,
	listen_socket: steam.HSteamListenSocket
}

Connection :: struct {}

main :: proc () {
	S = new(Server); defer free(S)

	start_steamworks(S)
	network_init(S)
	
	for ; true ; {
		steam_callbacks(S)
		network_tick(S)
		free_all(context.temp_allocator)
		time.sleep(SERVER_TICK_PERIOD-time.since(S.network_tick))
	}

	steam.Shutdown()
}

network_init :: proc (server : ^Server) {
	server.network_tick = time.now()
}

network_tick :: proc (server : ^Server) {
	since_last_tick := time.since(server.network_tick)
	if since_last_tick < SERVER_TICK_PERIOD do return
	server.network_tick = time.now()
	MAX_MSGS :: 256
	messages: [MAX_MSGS]^steam.SteamNetworkingMessage
	msg_count := steam.NetworkingSockets_ReceiveMessagesOnPollGroup(steam.NetworkingSockets_SteamAPI(), server.poll_group, &messages[0], MAX_MSGS)
	for i in 0..<msg_count {
		message := messages[i]
		defer steam.NetworkingMessage_t_Release(message)
		data_ptr := cast([^]u8)message^.pData
        data := data_ptr[:message^.cbSize]
		msg, err := core.deserialize_msg(data, context.temp_allocator)
		if err != nil {fmt.println("Failed to deserialize msg"); continue}
		handle_msg(server, msg)
	} // need to do it again if count == MAX_MSGS
	
	broadcast_GameState(server)
}

handle_msg :: proc (server : ^Server, msg : core.Msg) {
	input_msgs := make([dynamic]core.MsgPlayerInput, context.temp_allocator)
	switch m in msg {
	case core.MsgPlayerInput:
		append(&input_msgs, m)
	case core.MsgGameState:

	}
	core.state_update(&server.game_state, input_msgs[:])
}

broadcast_GameState :: proc (server : ^Server) {
	msg_bytes, err := core.serialize_msg(core.MsgGameState{server.game_state}, context.temp_allocator)
	for connection in server.connections {
		steam.NetworkingSockets_SendMessageToConnection(steam.NetworkingSockets_SteamAPI(), connection, raw_data(msg_bytes), u32(len(msg_bytes)), steam.nSteamNetworkingSend_Unreliable, nil)
	}
}
