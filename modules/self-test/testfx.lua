--
-- tests/testfx.lua
-- Automated test framework for Premake.
-- Copyright (c) 2008-2015 Jason Perkins and the Premake project
--

	local p = premake

	local m = p.modules.self_test


--
-- Define a namespace for the testing functions
--

	m.suppressed = {}


--
-- Capture stderr for testing.
--

	local stderr_capture = nil

	local mt = getmetatable(io.stderr)
	local builtin_write = mt.write
	mt.write = function(...)
		if select(1,...) == io.stderr then
			stderr_capture = (stderr_capture or "") .. select(2,...)
		else
			return builtin_write(...)
		end
	end


--
-- Assertion functions
--

	function m.capture(expected)
		local actual = premake.captured() .. premake.eol()

		-- create line-by-line iterators for both values
		local ait = actual:gmatch("(.-)" .. premake.eol())
		local eit = expected:gmatch("(.-)\n")

		-- compare each value line by line
		local linenum = 1
		local atxt = ait()
		local etxt = eit()
		while etxt do
			if (etxt ~= atxt) then
				m.fail("(%d) expected:\n%s\n...but was:\n%s", linenum, etxt, atxt)
			end

			linenum = linenum + 1
			atxt = ait()
			etxt = eit()
		end
	end


	function m.closedfile(expected)
		if expected and not m.value_closedfile then
			m.fail("expected file to be closed")
		elseif not expected and m.value_closedfile then
			m.fail("expected file to remain open")
		end
	end


	function m.contains(expected, actual)
		if type(expected) == "table" then
			for i, v in ipairs(expected) do
				m.contains(v, actual)
			end
		elseif not table.contains(actual, expected) then
			m.fail("expected value %s not found", expected)
		end
	end


	function m.excludes(expected, actual)
		if type(expected) == "table" then
			for i, v in ipairs(expected) do
				m.excludes(v, actual)
			end
		elseif table.contains(actual, expected) then
			m.fail("excluded value %s found", expected)
		end
	end


	function m.fail(format, ...)

		-- if format is a number then it is the stack depth
		local depth = 3
		local arg = {...}
		if type(format) == "number" then
			depth = depth + format
			format = table.remove(arg, 1)
		end

		-- convert nils into something more usefuls
		for i = 1, #arg do
			if (arg[i] == nil) then
				arg[i] = "(nil)"
			elseif (type(arg[i]) == "table") then
				arg[i] = "{" .. table.concat(arg[i], ", ") .. "}"
			end
		end

		local msg = string.format(format, unpack(arg))
		error(debug.traceback(msg, depth), depth)
	end


	function m.filecontains(expected, fn)
		local f = io.open(fn)
		local actual = f:read("*a")
		f:close()
		if (expected ~= actual) then
			m.fail("expected %s but was %s", expected, actual)
		end
	end


	function m.hasoutput()
		local actual = premake.captured()
		if actual == "" then
			m.fail("expected output, received none");
		end
	end


	function m.isemptycapture()
		local actual = premake.captured()
		if actual ~= "" then
			m.fail("expected empty capture, but was %s", actual);
		end
	end


	function m.isequal(expected, actual, depth)
		depth = depth or 0
		if type(expected) == "table" then
			if expected and not actual then
				m.fail(depth, "expected table, got nil")
			end
			if #expected < #actual then
				m.fail(depth, "expected %d items, got %d", #expected, #actual)
			end
			for k,v in pairs(expected) do
				m.isequal(expected[k], actual[k], depth + 1)
			end
		else
			if (expected ~= actual) then
				m.fail(depth, "expected %s but was %s", expected, actual)
			end
		end
		return true
	end


	function m.isfalse(value)
		if (value) then
			m.fail("expected false but was true")
		end
	end


	function m.isnil(value)
		if (value ~= nil) then
			m.fail("expected nil but was " .. tostring(value))
		end
	end


	function m.isnotnil(value)
		if (value == nil) then
			m.fail("expected not nil")
		end
	end


	function m.issame(expected, action)
		if expected ~= action then
			m.fail("expected same value")
		end
	end


	function m.istrue(value)
		if (not value) then
			m.fail("expected true but was false")
		end
	end

	function m.missing(value, actual)
		if table.contains(actual, value) then
			m.fail("unexpected value %s found", value)
		end
	end

	function m.openedfile(fname)
		if fname ~= m.value_openedfilename then
			local msg = "expected to open file '" .. fname .. "'"
			if m.value_openedfilename then
				msg = msg .. ", got '" .. m.value_openedfilename .. "'"
			end
			m.fail(msg)
		end
	end


	function m.success(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			m.fail("call failed: " .. err)
		end
	end


	function m.stderr(expected)
		if not expected and stderr_capture then
			m.fail("Unexpected: " .. stderr_capture)
		elseif expected then
			if not stderr_capture or not stderr_capture:find(expected) then
				m.fail(string.format("expected '%s'; got %s", expected, stderr_capture or "(nil)"))
			end
		end
	end


	function m.notstderr(expected)
		if not expected and not stderr_capture then
			m.fail("Expected output on stderr; none received")
		elseif expected then
			if stderr_capture and stderr_capture:find(expected) then
				m.fail(string.format("stderr contains '%s'; was %s", expected, stderr_capture))
			end
		end
	end


--
-- Some helper functions
--

	function m.createWorkspace()
		local wks = workspace("MyWorkspace")
		configurations { "Debug", "Release" }
		local prj = m.createproject(wks)
		return wks, prj
	end

	-- Eventually we'll want to deprecate this one and move everyone
	-- over to createWorkspace() instead (4 Sep 2015).
	function m.createsolution()
		local wks = workspace("MySolution")
		configurations { "Debug", "Release" }
		local prj = m.createproject(wks)
		return wks, prj
	end


	function m.createproject(wks)
		local n = #wks.projects + 1
		if n == 1 then n = "" end

		local prj = project ("MyProject" .. n)
		language "C++"
		kind "ConsoleApp"
		return prj
	end


	function m.getWorkspace(wks)
		p.oven.bake()
		return p.global.getWorkspace(wks.name)
	end

	p.alias(m, "getWorkspace", "getsolution")


	function m.getproject(wks, i)
		wks = m.getWorkspace(wks)
		return p.workspace.getproject(wks, i or 1)
	end


	function m.getconfig(prj, buildcfg, platform)
		local wks = m.getWorkspace(prj.workspace)
		prj = p.workspace.getproject(wks, prj.name)
		return p.project.getconfig(prj, buildcfg, platform)
	end



--
-- Test execution function
--
	local _OS_host = _OS
	local _OPTIONS_host = _OPTIONS

	local function error_handler(err)
		local msg = err

		-- if the error doesn't include a stack trace, add one
		if not msg:find("stack traceback:", 1, true) then
			msg = debug.traceback(err, 2)
		end

		-- trim of the trailing context of the originating xpcall
		local i = msg:find("[C]: in function 'xpcall'", 1, true)
		if i then
			msg = msg:sub(1, i - 3)
		end

		-- if the resulting stack trace is only one level deep, ignore it
		local n = select(2, msg:gsub('\n', '\n'))
		if n == 2 then
			msg = msg:sub(1, msg:find('\n', 1, true) - 1)
		end

		return msg
	end


	local function test_setup(suite, fn)
		_ACTION = "test"
		_OS = _OS_host

		_OPTIONS = {}
		setmetatable(_OPTIONS, getmetatable(_OPTIONS_host))

		stderr_capture = nil

		premake.clearWarnings()
		premake.eol("\n")
		premake.escaper(nil)
		premake.indent("\t")
		premake.api.reset()

		-- reset captured I/O values
		m.value_openedfilename = nil
		m.value_openedfilemode = nil
		m.value_closedfile = false

		if suite.setup then
			return xpcall(suite.setup, error_handler)
		else
			return true
		end
	end


	local function test_run(suite, fn)
		local result, err
		premake.capture(function()
			result, err = xpcall(fn, error_handler)
		end)
		return result, err
	end


	local function test_teardown(suite, fn)
		if suite.teardown then
			return xpcall(suite.teardown, error_handler)
		else
			return true
		end
	end



	function m.suppress(id)
		if type(id) == "table" then
			for i = 1, #id do
				m.suppress(id[i])
			end
		else
			m.suppressed[id] = true
		end
	end



	m.print = print



	function m.runTests(identifier)
		local suitename, testname = m.parseTestIdentifier(identifier)

		local hooks = m.installTestingHooks()

		local startTime = os.clock()

		local numpassed = 0
		local numfailed = 0

		function runtest(suitename, suitetests, testname, testfunc)
			if suitetests.setup ~= testfunc and
				suitetests.teardown ~= testfunc and
				not m.suppressed[suitename .. "." .. testname]
			then
				local ok, err = test_setup(suitetests, testfunc)

				if ok then
					ok, err = test_run(suitetests, testfunc)
				end

				local tok, terr = test_teardown(suitetests, testfunc)
				ok = ok and tok
				err = err or terr

				if (not ok) then
					m.print(string.format("%s.%s: %s", suitename, testname, err))
					numfailed = numfailed + 1
				else
					numpassed = numpassed + 1
				end
			end
		end


		function runsuite(suitename, suitetests, testname)
			if suitetests and not m.suppressed[suitename] then
				_TESTS_DIR = suitetests._TESTS_DIR
				_SCRIPT_DIR = suitetests._SCRIPT_DIR

				if testname then
					runtest(suitename, suitetests, testname, suitetests[testname])
				else
					for testname, testfunc in pairs(suitetests) do
						if type(testfunc) == "function" then
							runtest(suitename, suitetests, testname, testfunc)
						end
					end
				end
			end
		end

		if suitename then
			runsuite(suitename, T[suitename], testname)
		else
			for suitename, suitetests in pairs(T) do
				runsuite(suitename, suitetests, testname)
			end
		end

		local result = {
			passed = numpassed,
			failed = numfailed,
			start = startTime,
			elapsed = os.clock() - startTime
		}

		m.removeTestingHooks(hooks)

		return result
	end

