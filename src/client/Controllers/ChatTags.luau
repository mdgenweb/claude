-- Foundry VIP chat tag. The server sets the IsVIP attribute ahead of time because
-- chat callbacks must never yield.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.init()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		if not source then
			return nil
		end
		local sender = Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("IsVIP") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = "<font color='#FFD12E'>[VIP]</font> " .. message.PrefixText
			return props
		end
		return nil
	end
end

return ChatTags
