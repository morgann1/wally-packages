--!strict
-- Entry point for the test place: runs every *.spec under
-- ReplicatedStorage.Tests with Jest and errors when anything fails, so
-- run-in-roblox exits non-zero. Invoked by `lute run .lute/test.luau`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ReactRoblox.act (used by the foundation spec) requires React's mock
-- scheduler, and React captures this flag when its modules first load —
-- so it must be set before anything requires the shared React tree.
_G.__ROACT_17_MOCK_SCHEDULER__ = true

local DevPackages = ReplicatedStorage:WaitForChild("DevPackages") :: Folder
local Tests = ReplicatedStorage:WaitForChild("Tests") :: Folder

local Jest = require(DevPackages:WaitForChild("Jest"))

local status, payload = Jest.runCLI(Tests, {
	verbose = true,
	ci = false,
}, { Tests }):awaitStatus()

if status ~= "Resolved" then
	error(`Jest promise rejected: {tostring(payload)}`, 0)
end

local results = (payload :: any).results
if results == nil then
	error("Jest returned no results payload", 0)
end
if results.numFailedTestSuites > 0 or results.numFailedTests > 0 then
	error(`Jest: {results.numFailedTests} test(s) and {results.numFailedTestSuites} suite(s) failed`, 0)
end

print("Jest: all tests passed")
