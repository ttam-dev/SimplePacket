--!strict
--!optimize 2
--!native

--[[
	S16		Minimum: -32768			Maximum: 32767

	U8		Minimum: 0				Maximum: 255
	U16		Minimum: 0				Maximum: 65535
	U24		Minimum: 0				Maximum: 16777215
	U32		Minimum: 0				Maximum: 4294967295

	F32		±16777216				[170141183460469231731687303715884105728]
	F64		±9007199254740992		[huge]
]]

-- Types
export type Cursor = {
	Buffer: buffer,
	BufferLength: number,
	BufferOffset: number,
	Instances: { Instance },
	InstancesOffset: number,
}

-- Varables
local activeCursor: Cursor
local activeBuffer: buffer
local bufferLength: number
local bufferOffset: number
local instances: { Instance }
local instancesOffset: number
local reads = {}
local writes = {}
local anyReads = {} :: { [any]: () -> any }
local anyWrites = {} :: { [any]: (any) -> () }
local enumIndices = {}
local enums = require(script.Enums)
for index, static in enums do
	enumIndices[static] = index
end

-- Functions
local function Allocate(bytes: number)
	local targetLength = bufferOffset + bytes
	if bufferLength < targetLength then
		while bufferLength < targetLength do
			bufferLength *= 2
		end
		local newBuffer = buffer.create(bufferLength)
		buffer.copy(newBuffer, 0, activeBuffer, 0, bufferOffset)
		activeCursor.Buffer = newBuffer
		activeBuffer = newBuffer
	end
end

local function ReadS16(): number
	local value = buffer.readi16(activeBuffer, bufferOffset)
	bufferOffset += 2
	return value
end
local function WriteS16(value: number)
	buffer.writei16(activeBuffer, bufferOffset, value)
	bufferOffset += 2
end
local function ReadU8(): number
	local value = buffer.readu8(activeBuffer, bufferOffset)
	bufferOffset += 1
	return value
end
local function WriteU8(value: number)
	buffer.writeu8(activeBuffer, bufferOffset, value)
	bufferOffset += 1
end
local function ReadU16(): number
	local value = buffer.readu16(activeBuffer, bufferOffset)
	bufferOffset += 2
	return value
end
local function WriteU16(value: number)
	buffer.writeu16(activeBuffer, bufferOffset, value)
	bufferOffset += 2
end
local function ReadU24(): number
	local value = buffer.readbits(activeBuffer, bufferOffset * 8, 24)
	bufferOffset += 3
	return value
end
local function WriteU24(value: number)
	buffer.writebits(activeBuffer, bufferOffset * 8, 24, value)
	bufferOffset += 3
end
local function ReadU32(): number
	local value = buffer.readu32(activeBuffer, bufferOffset)
	bufferOffset += 4
	return value
end
local function WriteU32(value: number)
	buffer.writeu32(activeBuffer, bufferOffset, value)
	bufferOffset += 4
end
local function ReadF32(): number
	local value = buffer.readf32(activeBuffer, bufferOffset)
	bufferOffset += 4
	return value
end
local function WriteF32(value: number)
	buffer.writef32(activeBuffer, bufferOffset, value)
	bufferOffset += 4
end
local function ReadF64(): number
	local value = buffer.readf64(activeBuffer, bufferOffset)
	bufferOffset += 8
	return value
end
local function WriteF64(value: number)
	buffer.writef64(activeBuffer, bufferOffset, value)
	bufferOffset += 8
end
local function ReadString(length: number)
	local value = buffer.readstring(activeBuffer, bufferOffset, length)
	bufferOffset += length
	return value
end
local function WriteString(value: string)
	buffer.writestring(activeBuffer, bufferOffset, value)
	bufferOffset += #value
end
local function ReadBuffer(length: number)
	local value = buffer.create(length)
	buffer.copy(value, 0, activeBuffer, bufferOffset, length)
	bufferOffset += length
	return value
end
local function WriteBuffer(value: buffer)
	buffer.copy(activeBuffer, bufferOffset, value)
	bufferOffset += buffer.len(value)
end
local function ReadInstance()
	instancesOffset += 1
	return instances[instancesOffset]
end
local function WriteInstance(value)
	instancesOffset += 1
	instances[instancesOffset] = value
end

-- Types
reads.Any = function()
	return anyReads[ReadU8()]()
end
writes.Any = function(value: any)
	anyWrites[typeof(value)](value)
end

reads.NumberU8 = function()
	return ReadU8()
end
writes.NumberU8 = function(value: number)
	Allocate(1)
	WriteU8(value)
end

-- Any Types
anyReads[0] = function()
	return nil
end
anyWrites["nil"] = function(value: nil)
	Allocate(1)
	WriteU8(0)
end

anyReads[1] = function()
	return -ReadU8()
end
anyReads[2] = function()
	return -ReadU16()
end
anyReads[3] = function()
	return -ReadU24()
end
anyReads[4] = function()
	return -ReadU32()
end
anyReads[5] = function()
	return ReadU8()
end
anyReads[6] = function()
	return ReadU16()
end
anyReads[7] = function()
	return ReadU24()
end
anyReads[8] = function()
	return ReadU32()
end
anyReads[9] = function()
	return ReadF32()
end
anyReads[10] = function()
	return ReadF64()
end
anyWrites.number = function(value: number)
	if value % 1 == 0 then
		if value < 0 then
			if value > -256 then
				Allocate(2)
				WriteU8(1)
				WriteU8(-value)
			elseif value > -65536 then
				Allocate(3)
				WriteU8(2)
				WriteU16(-value)
			elseif value > -16777216 then
				Allocate(4)
				WriteU8(3)
				WriteU24(-value)
			elseif value > -4294967296 then
				Allocate(5)
				WriteU8(4)
				WriteU32(-value)
			else
				Allocate(9)
				WriteU8(10)
				WriteF64(value)
			end
		else
			if value < 256 then
				Allocate(2)
				WriteU8(5)
				WriteU8(value)
			elseif value < 65536 then
				Allocate(3)
				WriteU8(6)
				WriteU16(value)
			elseif value < 16777216 then
				Allocate(4)
				WriteU8(7)
				WriteU24(value)
			elseif value < 4294967296 then
				Allocate(5)
				WriteU8(8)
				WriteU32(value)
			else
				Allocate(9)
				WriteU8(10)
				WriteF64(value)
			end
		end
	elseif value > -1048576 and value < 1048576 then
		Allocate(5)
		WriteU8(9)
		WriteF32(value)
	else
		Allocate(9)
		WriteU8(10)
		WriteF64(value)
	end
end

anyReads[11] = function()
	return ReadString(ReadU8())
end
anyWrites.string = function(value: string)
	local length = #value
	Allocate(2 + length)
	WriteU8(11)
	WriteU8(length)
	WriteString(value)
end

anyReads[12] = function()
	return ReadBuffer(ReadU8())
end
anyWrites.buffer = function(value: buffer)
	local length = buffer.len(value)
	Allocate(2 + length)
	WriteU8(12)
	WriteU8(length)
	WriteBuffer(value)
end

anyReads[13] = function()
	return ReadInstance()
end
anyWrites.Instance = function(value: Instance)
	Allocate(1)
	WriteU8(13)
	WriteInstance(value)
end

anyReads[14] = function()
	return ReadU8() == 1
end
anyWrites.boolean = function(value: boolean)
	Allocate(2)
	WriteU8(14)
	WriteU8(if value then 1 else 0)
end

anyReads[15] = function()
	return NumberRange.new(ReadF32(), ReadF32())
end
anyWrites.NumberRange = function(value: NumberRange)
	Allocate(9)
	WriteU8(15)
	WriteF32(value.Min)
	WriteF32(value.Max)
end

anyReads[16] = function()
	return BrickColor.new(ReadU16())
end
anyWrites.BrickColor = function(value: BrickColor)
	Allocate(3)
	WriteU8(16)
	WriteU16(value.Number)
end

anyReads[17] = function()
	return Color3.fromRGB(ReadU8(), ReadU8(), ReadU8())
end
anyWrites.Color3 = function(value: Color3)
	Allocate(4)
	WriteU8(17)
	WriteU8(value.R * 255 + 0.5)
	WriteU8(value.G * 255 + 0.5)
	WriteU8(value.B * 255 + 0.5)
end

anyReads[18] = function()
	return UDim.new(ReadS16() / 1000, ReadS16())
end
anyWrites.UDim = function(value: UDim)
	Allocate(5)
	WriteU8(18)
	WriteS16(value.Scale * 1000)
	WriteS16(value.Offset)
end

anyReads[19] = function()
	return UDim2.new(ReadS16() / 1000, ReadS16(), ReadS16() / 1000, ReadS16())
end
anyWrites.UDim2 = function(value: UDim2)
	Allocate(9)
	WriteU8(19)
	WriteS16(value.X.Scale * 1000)
	WriteS16(value.X.Offset)
	WriteS16(value.Y.Scale * 1000)
	WriteS16(value.Y.Offset)
end

anyReads[20] = function()
	return Rect.new(ReadF32(), ReadF32(), ReadF32(), ReadF32())
end
anyWrites.Rect = function(value: Rect)
	Allocate(17)
	WriteU8(20)
	WriteF32(value.Min.X)
	WriteF32(value.Min.Y)
	WriteF32(value.Max.X)
	WriteF32(value.Max.Y)
end

anyReads[21] = function()
	return Vector2.new(ReadF32(), ReadF32())
end
anyWrites.Vector2 = function(value: Vector2)
	Allocate(9)
	WriteU8(21)
	WriteF32(value.X)
	WriteF32(value.Y)
end

anyReads[22] = function()
	return Vector3.new(ReadF32(), ReadF32(), ReadF32())
end
anyWrites.Vector3 = function(value: Vector3)
	Allocate(13)
	WriteU8(22)
	WriteF32(value.X)
	WriteF32(value.Y)
	WriteF32(value.Z)
end

anyReads[23] = function()
	return CFrame.fromEulerAnglesXYZ(
		ReadU16() / 10430.219195527361,
		ReadU16() / 10430.219195527361,
		ReadU16() / 10430.219195527361
	) + Vector3.new(ReadF32(), ReadF32(), ReadF32())
end
anyWrites.CFrame = function(value: CFrame)
	local rx, ry, rz = value:ToEulerAnglesXYZ()
	Allocate(19)
	WriteU8(23)
	WriteU16(rx * 10430.219195527361 + 0.5)
	WriteU16(ry * 10430.219195527361 + 0.5)
	WriteU16(rz * 10430.219195527361 + 0.5)
	WriteF32(value.X)
	WriteF32(value.Y)
	WriteF32(value.Z)
end

anyReads[24] = function()
	return Region3.new(Vector3.new(ReadF32(), ReadF32(), ReadF32()), Vector3.new(ReadF32(), ReadF32(), ReadF32()))
end
anyWrites.Region3 = function(value: Region3)
	local halfSize = value.Size / 2
	local minimum = value.CFrame.Position - halfSize
	local maximum = value.CFrame.Position + halfSize
	Allocate(25)
	WriteU8(24)
	WriteF32(minimum.X)
	WriteF32(minimum.Y)
	WriteF32(minimum.Z)
	WriteF32(maximum.X)
	WriteF32(maximum.Y)
	WriteF32(maximum.Z)
end

anyReads[25] = function()
	local length = ReadU8()
	local keypoints = table.create(length)
	for _ = 1, length do
		table.insert(keypoints, NumberSequenceKeypoint.new(ReadU8() / 255, ReadU8() / 255, ReadU8() / 255))
	end
	return NumberSequence.new(keypoints)
end
anyWrites.NumberSequence = function(value: NumberSequence)
	local length = #value.Keypoints
	Allocate(2 + length * 3)
	WriteU8(25)
	WriteU8(length)
	for _, keypoint in value.Keypoints do
		WriteU8(keypoint.Time * 255 + 0.5)
		WriteU8(keypoint.Value * 255 + 0.5)
		WriteU8(keypoint.Envelope * 255 + 0.5)
	end
end

anyReads[26] = function()
	local length = ReadU8()
	local keypoints = table.create(length)
	for _ = 1, length do
		table.insert(keypoints, ColorSequenceKeypoint.new(ReadU8() / 255, Color3.fromRGB(ReadU8(), ReadU8(), ReadU8())))
	end
	return ColorSequence.new(keypoints)
end
anyWrites.ColorSequence = function(value: ColorSequence)
	local length = #value.Keypoints
	Allocate(2 + length * 4)
	WriteU8(26)
	WriteU8(length)
	for _, keypoint in value.Keypoints do
		WriteU8(keypoint.Time * 255 + 0.5)
		WriteU8(keypoint.Value.R * 255 + 0.5)
		WriteU8(keypoint.Value.G * 255 + 0.5)
		WriteU8(keypoint.Value.B * 255 + 0.5)
	end
end

anyReads[27] = function()
	return enums[ReadU8()]:FromValue(ReadU16())
end
anyWrites.EnumItem = function(value: EnumItem)
	Allocate(4)
	WriteU8(27)
	WriteU8(enumIndices[value.EnumType])
	WriteU16(value.Value)
end

anyReads[28] = function()
	local value = {}
	while true do
		local typeId = ReadU8()
		if typeId == 0 then
			return value
		else
			value[anyReads[typeId]()] = anyReads[ReadU8()]()
		end
	end
end
anyWrites.table = function(value: { [any]: any })
	Allocate(1)
	WriteU8(28)
	for index, value in value do
		anyWrites[typeof(index)](index)
		anyWrites[typeof(value)](value)
	end
	Allocate(1)
	WriteU8(0)
end

return {
	Import = function(cursor: Cursor)
		activeCursor = cursor
		activeBuffer = cursor.Buffer
		bufferLength = cursor.BufferLength
		bufferOffset = cursor.BufferOffset
		instances = cursor.Instances
		instancesOffset = cursor.InstancesOffset
	end,

	Export = function()
		activeCursor.BufferLength = bufferLength
		activeCursor.BufferOffset = bufferOffset
		activeCursor.InstancesOffset = instancesOffset
		return activeCursor
	end,

	Truncate = function()
		local truncatedBuffer = buffer.create(bufferOffset)
		buffer.copy(truncatedBuffer, 0, activeBuffer, 0, bufferOffset)
		if instancesOffset == 0 then
			return truncatedBuffer
		else
			return truncatedBuffer, instances
		end
	end,

	Ended = function()
		return bufferOffset >= bufferLength
	end,

	Reads = reads,
	Writes = writes,
}
