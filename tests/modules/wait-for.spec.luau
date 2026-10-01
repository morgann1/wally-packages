--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Promise = require(ReplicatedStorage.Packages.PromiseLuau)
local WaitFor = require(ReplicatedStorage.Modules["wait-for"]["wait-for"])

-- Each test builds under its own root, which stays outside the DataModel.
local root: Folder

local function create(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

describe("wait-for", function()
	beforeEach(function()
		root = Instance.new("Folder")
	end)

	afterEach(function()
		root:Destroy()
	end)

	test("Child resolves when the named child is added later", function()
		task.defer(create, "Other", root)
		task.defer(create, "Target", root)

		local child = WaitFor.Child(root, "Target"):expect()
		expect(child.Name).toBe("Target")
		expect(child.Parent).toBe(root)
	end)

	test("Child rejects with Unparented when the parent's ancestor leaves", function()
		local parent = create("Parent", create("Middle", root))
		task.defer(function()
			(parent.Parent :: Instance).Parent = nil
		end)

		local ok, err = WaitFor.Child(parent, "Never"):await()
		expect(ok).toBe(false)
		expect(err).toBe(WaitFor.Error.Unparented)
	end)

	test("Child rejects with a TimedOut error after the timeout", function()
		local ok, err = WaitFor.Child(root, "Never", 0.05):await()
		expect(ok).toBe(false)
		expect(Promise.Error.isKind(err, Promise.Error.Kind.TimedOut)).toBe(true)
	end)

	test("Children resolves in the requested order", function()
		task.delay(0.05, create, "A", root)
		task.defer(create, "B", root)

		local children = WaitFor.Children(root, { "A", "B" }):expect()
		expect(children[1].Name).toBe("A")
		expect(children[2].Name).toBe("B")
	end)

	test("Children rejects with ParentChanged when a found child moves away", function()
		local early = create("Early", root)
		task.defer(function()
			early.Parent = nil
			create("Late", root)
		end)

		local ok, err = WaitFor.Children(root, { "Early", "Late" }):await()
		expect(ok).toBe(false)
		expect(err).toBe(WaitFor.Error.ParentChanged)
	end)

	test("Descendants resolves nested descendants in the requested order", function()
		task.defer(create, "Deep", create("Inner", root))
		task.delay(0.05, create, "Shallow", root)

		local descendants = WaitFor.Descendants(root, { "Shallow", "Deep" }):expect()
		expect(descendants[1].Name).toBe("Shallow")
		expect(descendants[2].Name).toBe("Deep")
		expect(descendants[2]:IsDescendantOf(root)).toBe(true)
	end)

	test("Descendants rejects with ParentChanged when a found descendant leaves", function()
		local early = create("Early", create("Inner", root))
		task.defer(function()
			early.Parent = nil
			create("Late", root)
		end)

		local ok, err = WaitFor.Descendants(root, { "Early", "Late" }):await()
		expect(ok).toBe(false)
		expect(err).toBe(WaitFor.Error.ParentChanged)
	end)

	test("PrimaryPart resolves once the model's PrimaryPart is set", function()
		local model = Instance.new("Model")
		model.Parent = root
		local part = Instance.new("Part")
		part.Parent = model

		task.defer(function()
			model.PrimaryPart = part
		end)

		expect(WaitFor.PrimaryPart(model):expect()).toBe(part)
	end)

	test("ObjectValue resolves once Value is set", function()
		local objectValue = Instance.new("ObjectValue")
		objectValue.Parent = root
		local target = create("Target", root)

		task.defer(function()
			objectValue.Value = target
		end)

		expect(WaitFor.ObjectValue(objectValue):expect()).toBe(target)
	end)

	test("Custom resolves with the predicate's first non-nil value", function()
		local value: Folder? = nil
		task.delay(0.05, function()
			value = create("Value", root)
		end)

		local result = WaitFor.Custom(function()
			return value
		end):expect()
		expect(result).toBe(value)
	end)
end)
