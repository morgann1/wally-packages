--!strict
--!nolint LocalShadow
-- Originally (c) Studio Elttob 2024.

local HttpService = game:GetService("HttpService")

local Package = script.Parent

local ty = require(Package.Parent.ty)
local Types = require(Package.Types)

local MessageId = ty.String
local Args = Types.NetworkSafe:Array()

local function channel(medium: BindableEvent): Types.ChannelApi
	local sentByMe: { [string?]: true } = {}
	return {
		send = function(
			args: { Types.NetworkSafe },
			responseHandler: Types.ResponseHandler?,
			timeout: number?,
			timeoutHandler: (() -> ())?
		): (() -> ())?
			if timeout == nil then
				assert(responseHandler == nil, "Timeout required when a response is expected")
				timeout = 0.1
			end
			assert(Types.NetworkSafe:Matches(args), "Attempt to send with network unsafe arguments")
			local messageId: string = HttpService:GenerateGUID(false)
			local responseConn: RBXScriptConnection? = nil
			local timeoutThread: thread? = nil
			if responseHandler ~= nil then
				responseConn = medium.Event:Connect(
					function(incomingMessageId: unknown, messageType: unknown, args: unknown): ()
						if
							responseConn ~= nil
							and incomingMessageId == messageId
							and messageType == "response"
							and Args:Matches(args)
						then
							local action = responseHandler(args :: any)
							if action == "continue" then
								-- Do nothing.
							elseif action == "disconnect" then
								responseConn:Disconnect()
								responseConn = nil
								sentByMe[messageId] = nil
								if timeoutThread ~= nil then
									task.cancel(timeoutThread)
									timeoutThread = nil
								end
							else
								error("Invalid action returned from response handler")
							end
						end
					end
				)

				timeoutThread = task.delay(timeout, function()
					if responseConn ~= nil then
						responseConn:Disconnect()
						responseConn = nil
						timeoutThread = nil
						sentByMe[messageId] = nil
						if timeoutHandler ~= nil then
							timeoutHandler()
						end
					end
				end)
			end
			sentByMe[messageId] = true
			medium:Fire(messageId, if responseHandler == nil then "notExpectingResponse" else "expectingResponse", args)
			return if responseConn == nil
				then nil
				else function()
					if responseConn :: RBXScriptConnection? ~= nil then
						responseConn:Disconnect()
						responseConn = nil
					end
				end
		end,

		receive = function(receiveHandler: Types.ReceiveHandler): () -> ()
			local connected = true
			local responseConn: RBXScriptConnection
			responseConn = medium.Event:Connect(
				function(incomingMessageId: unknown, messageType: unknown, args: unknown): ()
					if
						connected
							and MessageId:Matches(incomingMessageId)
							and sentByMe[incomingMessageId :: any] ~= true
							and messageType == "expectingResponse"
						or messageType == "notExpectingResponse" and Args:Matches(args)
					then
						local action = receiveHandler(
							args :: any,
							if messageType == "notExpectingResponse"
								then nil
								else function(args: { Types.NetworkSafe }): ()
									assert(
										Types.NetworkSafe:Matches(args),
										"Attempt to reply with network unsafe arguments"
									)
									medium:Fire(incomingMessageId, "response", args)
								end
						)
						if action == "continue" then
							-- Do nothing.
						elseif action == "disconnect" then
							connected = false
							responseConn:Disconnect()
						else
							error("Invalid action returned from receive handler")
						end
					end
				end
			)
			return function()
				if connected then
					connected = false
					responseConn:Disconnect()
				end
			end
		end,
	}
end

return channel
