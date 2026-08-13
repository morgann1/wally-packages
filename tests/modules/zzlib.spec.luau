--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local zzlib = require(ReplicatedStorage.Modules.zzlib.zzlib)

-- Fixtures generated with .NET's DeflateStream/GZipStream/ZipArchive from
-- the plaintexts below (checksums included), embedded as byte escapes.
local TEXT = "Hello, zzlib! Hello, zzlib! Hello, zzlib!\n"
local STORED_TEXT = "stored bytes"

local ZLIB = "\120\156\243\72\205\201\201\215\81\168\170\202\201\76\82\84\240\192\205\227\2\0\51\190\13\239"
local GZIP =
	"\31\139\8\0\0\0\0\0\0\10\243\72\205\201\201\215\81\168\170\202\201\76\82\84\240\192\205\227\2\0\44\162\172\165\42\0\0\0"
local ZIP =
	"\80\75\3\4\20\0\0\0\8\0\205\190\13\93\44\162\172\165\20\0\0\0\42\0\0\0\12\0\0\0\103\114\101\101\116\105\110\103\46\116\120\116\243\72\205\201\201\215\81\168\170\202\201\76\82\84\240\192\205\227\2\0\80\75\3\4\20\0\0\0\0\0\205\190\13\93\120\119\166\15\12\0\0\0\12\0\0\0\10\0\0\0\115\116\111\114\101\100\46\116\120\116\115\116\111\114\101\100\32\98\121\116\101\115\80\75\1\2\20\0\20\0\0\0\8\0\205\190\13\93\44\162\172\165\20\0\0\0\42\0\0\0\12\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\103\114\101\101\116\105\110\103\46\116\120\116\80\75\1\2\20\0\20\0\0\0\0\0\205\190\13\93\120\119\166\15\12\0\0\0\12\0\0\0\10\0\0\0\0\0\0\0\0\0\0\0\0\0\62\0\0\0\115\116\111\114\101\100\46\116\120\116\80\75\5\6\0\0\0\0\2\0\2\0\114\0\0\0\114\0\0\0\0\0"

describe("zzlib", function()
	test("inflate decompresses a zlib stream and verifies adler32", function()
		expect(zzlib.inflate(ZLIB)).toBe(TEXT)
	end)

	test("gunzip decompresses a gzip stream and verifies crc32", function()
		expect(zzlib.gunzip(GZIP)).toBe(TEXT)
	end)

	test("inflate rejects a corrupt zlib header", function()
		-- 0x78 0x00 fails the FCHECK bits: (0x78 * 256 + 0x00) % 31 ~= 0.
		expect(function()
			zzlib.inflate("\120\0garbage")
		end).toThrow("zlib header")
	end)

	test("files iterates every entry in a zip archive", function()
		local names = {}
		for _, name in zzlib.files(ZIP) do
			table.insert(names, name)
		end
		table.sort(names)
		expect(names).toEqual({ "greeting.txt", "stored.txt" })
	end)

	test("unzip extracts deflated and stored entries by name", function()
		expect(zzlib.unzip(ZIP, "greeting.txt")).toBe(TEXT)
		expect(zzlib.unzip(ZIP, "stored.txt")).toBe(STORED_TEXT)
	end)

	test("unzip errors for a missing entry", function()
		expect(function()
			zzlib.unzip(ZIP, "missing.txt")
		end).toThrow("not found in ZIP archive")
	end)
end)
