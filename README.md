# SimplePacket

**SimplePacket** is a simplified fork of the original [Packet](https://devforum.roblox.com/t/packet-networking-library/3573907) module by Suphi, designed for Roblox developers who prioritize ease of use and cleaner syntax in network communication.

## 🚀 What is SimplePacket?

SimplePacket reduces the boilerplate code required to create typed packets. While Suphi's Packet module emphasizes strict typing and maximum performance, SimplePacket streamlines the API so you only need to define the packet name—no extra argument types necessary.

### Suphi's Packet (original):

```lua
Packet("PlayerData", Packet.String, Packet.NumberU8)
```

### SimplePacket:

```lua
Packet("PlayerData")
```

## ⚖️ Trade-offs

By removing the requirement for explicit type declarations, SimplePacket:

- ✅ Simplifies the development workflow
- ✅ Offers a cleaner and faster setup for packets
- ⚠️ Slightly increases network and CPU usage
- ⚠️ Performs marginally slower than the original Packet module
- ✅ Still faster and more efficient than Roblox's native `RemoteEvent`

Overall, SimplePacket trades off a bit of speed and efficiency in favor of simplicity and developer experience.

## 📦 Installation

To use SimplePacket in your Roblox project:

1. Download the latest version.
2. Place the `SimplePacket` module into your `ReplicatedStorage` or any other accessible container.
3. Require it in both the client and server:

```lua
local Packet = require(game.ReplicatedStorage.SimplePacket)
```

## 📄 Usage

Create a packet:

```lua
local MyPacket = Packet("ChatMessage")
```

Send data:

```lua
-- Server
MyPacket:FireClient(player, "Hello!")
-- Client
MyPacket:Fire("Hi!")
```

Receive data:

```lua
-- Server
MyPacket.OnServerEvent:Connect(function(player, message)
    print(player.Name .. " says: " .. message)
end)
-- Client
MyPacket.OnClientEvent:Connect(function(message)
    print("Server: " .. message)
end)
```

## 🔧 Compatibility

SimplePacket is compatible with:

- Roblox Client-Server architecture
- Both client-side and server-side usage

## 🧠 Why Use SimplePacket?

If you're tired of declaring argument types every time you define a packet and are okay with a minor performance trade-off, SimplePacket can help speed up development while maintaining solid communication practices.

## 📜 License

This project is a fork of Suphi's [Packet module](https://devforum.roblox.com/t/packet-networking-library/3573907) and respects its original licensing terms where applicable.

---
> ⚠️ Disclaimer: This module simplifies usage at the cost of type safety and raw performance. For performance-critical systems, consider using the original Packet module.


