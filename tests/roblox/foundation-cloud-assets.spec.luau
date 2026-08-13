--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local FoundationCloudAssets =
	require(ReplicatedStorage.RobloxPackages["foundation-cloud-assets"]["foundation-cloud-assets"])

describe("foundation-cloud-assets", function()
	test("exports assets and the preloader", function()
		expect((next(FoundationCloudAssets.Assets))).never.toBeNil()
		expect(FoundationCloudAssets.preloadAsset).toEqual(expect.any("function"))
	end)
end)
