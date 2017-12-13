local function OpenOutputFile(ofile)
  local binfile	
  binfile, err = io.open(ofile, "wb")
  if binfile == nil then print(err) end
  math.randomseed(os.time())

  return binfile
end

local ldfEventCounter = 0

local hmonitor = nil

local monitored_channels = { [5] = true, [25] = true, [50] = true, [100] = true, [175] = true, [250] = true }

function GenerateLDFEvent()
  local data = {}
  data[1] = "DATA"
  data[2] = string.pack("<I4", 8192)

  ldfEventCounter = ldfEventCounter+1
  local evid = 8192

  print("**************** EVENT", ldfEventCounter,"******************")
  while evid > 0 do
    local multiplicity = math.random(1,3)

    if evid-multiplicity >= 1 then
      for i=1, multiplicity do
        local channel = math.random(0, 350)
        local value = math.random(0, 16384)

--    print("Draw random:", channel, value)

        if monitored_channels[channel] then hmonitor:Fill(channel) end

        local packaged = (value << 16) + channel

        data[evid+2] = string.pack("<I4", packaged)
        evid = evid-1
      end
      data[evid+2] = string.pack("<I4", 0xffffffff)

      evid = evid-1
    else
      for i=1, evid do
        data[evid+2] = string.pack("<I4", 0xffffffff)
        evid = evid-1
      end
    end
  end

  return table.concat(data)
end

pauseLDFGenerator = false
stopLDFGenerator = false

dataGenerator = nil

--function sleep(s)
--  local t0 = os.clock()
--  while os.clock() - t0 <= s do end
--end

function StartFillingOutput(output)
  print("exec func")
  local outfile = OpenOutputFile(output)
  ldfEventCounter = 0

  local minPause = 0.5

  print("file open")

  if hmonitor == nil then hmonitor = TH1({name = "h_monitor", title = "Monitor", xmin = 0, xmax = 351, nbinsx = 351}) end

  print("histograms initiated")

  hmonitor:Draw()

  print("histograms displayed")

  while CheckSignals() do
    local data = GenerateLDFEvent()
    outfile:write(data)

    local sleeptime = math.random(1, 300)*0.01

    hmonitor:Update()

    sleep(minPause+sleeptime)
  end

  print("done exec func")
end