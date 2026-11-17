package server
import "core:fmt"
import steam "../../ext/steamworks"
import "base:runtime"
import "core:c"
import "../core"

start_steamworks :: proc (server : ^Server) {
	if steam.RestartAppIfNecessary(steam.uAppIdInvalid) {
        fmt.println("Launching app through steam...")
        return
    }

    err_msg: steam.SteamErrMsg
    if err := steam.InitFlat(&err_msg); err != .OK {
        fmt.printfln("steam.InitFlat failed with code '{}' and message \"{}\"", err, transmute(cstring)&err_msg[0])
        panic("Steam Init failed. Make sure Steam is running.")
    }

    steam.Client_SetWarningMessageHook(steam.Client(), steam_debug_text_hook)

    steam.ManualDispatch_Init()

    if !steam.User_BLoggedOn(steam.User()) {
        panic("User isn't logged in.")
    } else {
        fmt.println("USER IS LOGGED IN")
    }

	address : steam.SteamNetworkingIPAddr
	steam.NetworkingIPAddr_Clear(&address)
	address.port = core.PORT
	server.listen_socket = steam.NetworkingSockets_CreateListenSocketIP(steam.NetworkingSockets_SteamAPI(), &address, 0, nil)

	server.poll_group = steam.NetworkingSockets_CreatePollGroup(steam.NetworkingSockets_SteamAPI())
}

steam_debug_text_hook :: proc "c" (severity: c.int, debugText: cstring) {
    // if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
    // if you add -debug_steamworksapi to the command-line, a lot of extra informational messages will also be sent
    runtime.print_string(string(debugText))

    if severity >= 1 {
        runtime.debug_trap()
    }
}

steam_callbacks :: proc(server : ^Server) {
    steam_pipe := steam.GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    cb: steam.CallbackMsg

    for steam.ManualDispatch_GetNextCallback(steam_pipe, &cb) {
		#partial switch cb.iCallback {
		case .SteamNetConnectionStatusChangedCallback:
			event := transmute(^steam.SteamNetConnectionStatusChangedCallback)cb.pubParam
			#partial switch event.info.eState {
            case .Connecting:
                if event.info.hListenSocket == server.listen_socket &&
                   server.listen_socket != steam.HSteamListenSocket_Invalid {
                	result := steam.NetworkingSockets_AcceptConnection(steam.NetworkingSockets_SteamAPI(), event.hConn)
					if result == .OK {
						fmt.println("Accept connection: ", result)
					}
                }
            case .Connected:
                fmt.println("Client connected: ", event.hConn)
				server.connections[event.hConn] = {}
				steam.NetworkingSockets_SetConnectionPollGroup(steam.NetworkingSockets_SteamAPI(), event.hConn, server.poll_group)
            case .ClosedByPeer, .ProblemDetectedLocally:
                fmt.println("Client disconnected: ", event.hConn)
                steam.NetworkingSockets_CloseConnection(steam.NetworkingSockets_SteamAPI(), event.hConn, 0, nil, false)
				delete_key(&server.connections, event.hConn)
            }
		}
        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}

