orruba_applycal = true

orruba_monitors = {}
haliases = {}

local mapping = require("ldf_unpacker/se84_mapping")
local calib = require("ldf_unpacker/se84_calibration")

ch_cal, det_cal = calib.readcal()

function AddMonitor(alias, hparams, fillfn)
  if type(alias) == "table" then
    fillfn = hparams
    hparams = alias
    alias = nil
  end

  local hname = hparams.name
  local htitle = hparams.title ~= nil and hparams.title or hparams.name
  local xmin = hparams.xmin
  local xmax = hparams.xmax
  local nbinsx = hparams.nbinsx

  local ymin = hparams.ymin
  local ymax = hparams.ymax
  local nbinsy = hparams.nbinsy

  orruba_monitors[hname] = { hist = (ymin == nil and TH1(hparams) or TH2(hparams)), type = (ymin == nil and "1D" or "2D"), fillfn = fillfn }
  if alias then haliases[alias] = {hist=orruba_monitors[hname].hist, type=orruba_monitors[hname].type} end
end

----------------------- Fill Functions ---------------------------

local function PrepareSX3Computation(detector, strip, useback)
  local pIter = detector:gmatch("%a+%d*")

  local det_type, det_id = pIter(), pIter()

  local order = mapping.det_prop[det_type].front.order

  local order_index = 2*(strip-1)+1

  local strip_right = order[order_index]
  local strip_left = order[order_index+1]

  local detKey1, detKey2 = detector.." f"..tostring(strip_right), detector.." f"..tostring(strip_left)
  local ch_right, ch_left = mapping.getchannel(detKey1), mapping.getchannel(detKey2)

  local GetEnSum

  if not useback then
    GetEnSum = function(ev)
      local en_sum = ev[ch_right] and ev[ch_left] and ev[ch_right]+ev[ch_left] or nil
      return en_sum, en_sum
    end
  else
    local backStrips = mapping.getchannels(detector, "b")
    GetEnSum = function(ev)
      local maxBack = 0
      for _, s in ipairs(backStrips) do
        local en_ = ev[s]
        if en_ and en_ > maxBack then
          maxBack = en_
        end
      end

      local en_sum = ev[ch_right] and ev[ch_left] and ev[ch_right]+ev[ch_left] or nil
      return en_sum, maxBack
    end
  end

  local GetEnDiff = function(ev)
    return ev[ch_left] - ev[ch_right]
  end

  return ch_left, ch_right, GetEnSum, GetEnDiff
end

local function GetResistiveSum(channel, ev)
  if channel%2 == 0 then
    return ev[channel] and ev[channel-1] and ev[channel]+ev[channel-1] or nil
  else
    return ev[channel] and ev[channel+1] and ev[channel]+ev[channel+1] or nil
  end
end

have_barrel = false
have_elastics = false

local fillfns = {
  FillChVsValue = function(hist, ev)
    for k, v in pairs(ev) do
      local en = orruba_applycal and (ch_cal[k] and ch_cal[k].calibrate and ch_cal[k]:calibrate(v, ev) or nil) or v
      if en then
        hist:Fill(k, en)
      end
    end
  end,

  CalibrateAndFillChVsValue = function(hists, ev, cal_ev)
    for k, v in pairs(ev) do
      local en = orruba_applycal and (ch_cal[k] and ch_cal[k].calibrate and ch_cal[k]:calibrate(v, ev) or nil) or v
      cal_ev[k] = en
      if en then
        for i, v in ipairs(hists) do
          v:Fill(k, en)
        end

        if not have_barrel and orruba_applycal and en > 4 and ((k >= 101 and k < 199) or (k >= 501 and k < 599 ))then
          have_barrel = true
        end

        if not have_elastics and orruba_applycal and k >= 633 and k <= 656 then
          local res_en_sum = GetResistiveSum(k, ev)
          if res_en_sum and res_en_sum > 3 then
            have_elastics = true
          end
        end
      end
    end
  end,

  FillSumResistive = function(ch1, ch2)
    return function(hist, ev)
      if ev[ch1] and ev[ch2] then
        hist:Fill(ev[ch1]+ev[ch2])
      end
    end
  end,

  FillIfValidChannel = function(channel)
    if type(channel) == "string" then
      channel = mapping.getchannel(channel)
    end

    return function(hist, ev)
      if ev[channel] then
        hist:Fill(ev[channel])
      end
    end
  end,

  FillIfValidChannels = function(chlist)
    if type(chlist[1]) == "string" then
      local newchlist = {}
      for i, v in ipairs(chlist) do
        newchlist[i] = mapping.getchannel(v)
      end

      chlist = newchlist
    end

    return function(hist, ev)
      for _, ch in ipairs(chlist) do
        if ev[ch] then 
          hist:Fill(ev[ch]) 
        end
      end
    end
  end,

  FillSX3LeftVsRight = function(detector, strip)
    local ch1, ch2 = PrepareSX3Computation(detector, strip)

    return function(hist, ev)
      if ev[ch1] and ev[ch2] then 
        hist:Fill(ev[ch1], ev[ch2])
      end
    end
  end,

  FillResistiveFrontSum = function(detector, strip)
    local ch1, ch2, GetEnSum = PrepareSX3Computation(detector, strip)

    return function(hist, ev)
      local en_sum = GetEnSum(ev)
      hist:Fill(en_sum)
    end
  end,

  FillSX3RelativePosition = function(detector, strip, useback)
    local ch_left, ch_right, GetEnSum, GetEnDiff = PrepareSX3Computation(detector, strip, useback)

    return function(hist, ev)
      if ev[ch_left] and ev[ch_right] then
        local en_sum1, ensum2 = GetEnSum(ev)
        local en_diff = GetEnDiff(ev)

        hist:Fill(en_diff/en_sum1)
      end
    end
  end,

  FillSX3EnergyVsPosition = function(detector, strip, useback)
    local ch_left, ch_right, GetEnSum, GetEnDiff = PrepareSX3Computation(detector, strip, useback)

    return function(hist, ev)
      if ev[ch_left] and ev[ch_right] then
        local en_sum1, ensum2 = GetEnSum(ev)
        local en_diff = GetEnDiff(ev)

        hist:Fill(en_diff/en_sum1, ensum2)
      end
    end
  end,

  FillCh1IfCh2 = function(ch1, ch2)
    if type(ch1) == "string" then
      ch1 = mapping.getchannel(ch1)
    end

    if type(ch2) == "string" then
      ch2 = mapping.getchannel(ch2)
    end

    return function(hist, ev)
      if ev[ch1] and ev[ch2] then
        hist:Fill(ev[ch1])
      end
    end
  end,

  FillCh1IfChlist = function(ch1, chlist, getall)
    if type(ch1) == "string" then
      ch1 = mapping.getchannel(ch1)
    end

    if type(chlist[1]) == "string" then
      for i, v in ipairs(chlist) do
        chlist[i] = mapping.getchannel(v)
      end
    end

    local validatefill

    if not getall then
      validatefill = function(ev, chlist)
        for _, ch in ipairs(chlist) do
          if ev[ch] then
            return true
          end
        end
        return false
      end
    else
      validatefill = function(ev, chlist)
        for _, ch in ipairs(chlist) do
          if not ev[ch] then
            return false
          end
        end
        return true
      end
    end

    return function(hist, ev)
      if ev[ch1] and validatefill(ev, chlist) then
        hist:Fill(ev[ch1])
      end
    end
  end,

  FillMCP = function(mcp_key, direction)
    local commonKey = mcp_key.." "
    local ch_tr = mapping.getchannel(commonKey.."TOP_RIGHT")
    local ch_tl = mapping.getchannel(commonKey.."TOP_LEFT")
    local ch_br = mapping.getchannel(commonKey.."BOTTOM_RIGHT")
    local ch_bl = mapping.getchannel(commonKey.."BOTTOM_LEFT")

    local dodiff

    if direction == "x" then
      dodiff = function(en_tr, en_tl, en_bl, en_br)
        return (en_tr+en_br) - (en_tl+en_bl)
      end
    elseif direction == "y" then
      dodiff = function(en_tr, en_tl, en_bl, en_br)
        return (en_tr+en_tl) - (en_br+en_bl)
      end
    elseif direction == "x vs. y" then
      return function(hist, ev)
        if ev[ch_tr] and ev[ch_tl] and ev[ch_br] and ev[ch_bl] then
          local en_sum = ev[ch_tl]+ev[ch_bl]+ev[ch_tr]+ev[ch_br]
          local diffx = (ev[ch_tl]+ev[ch_bl]) - (ev[ch_tr]+ev[ch_br])
          local diffy = (ev[ch_tr]+ev[ch_tl]) - (ev[ch_bl]+ev[ch_br])
          hist:Fill(diffx/en_sum, diffy/en_sum)
        end
      end
    end

    return function(hist, ev)
      if ev[ch_tr] and ev[ch_tl] and ev[ch_br] and ev[ch_bl] then
        local diff = dodiff(ev[ch_tr], ev[ch_tl], ev[ch_bl], ev[ch_br])
        hist:Fill(diff)
      end
    end
  end,

--  FillSIDAREnvsStrip = function(hist, ev)
--    if not orruba_applycal then return end

--    local exclude = { [102] = true, [176] = true, }

--    for k, v in pairs(ev) do
--      if k > 100 and k < 199 and not exclude[k] then
--        local en = (ch_cal[k] and ch_cal[k].calibrate and ch_cal[k]:calibrate(v, ev)) or nil
--        if en then
--          local stripnum = (k-101)%16
--          hist:Fill(stripnum, en)
--        end
--      end
--    end
--  end,

  FillSIDARGraphs = function(hist, ev)
    if not orruba_applycal then return end

    local exclude = {[2] = true, [3] = true, [9] = true, [44] = true, [48] = true, [76] = true, [102] = true, [176] = true, }

    for det=2, 16 do
      local first_ch = 101 + (det-1)*16

      local max_E_en = 0
      local max_E_strip = -1
      for ch = first_ch, first_ch+16 do
        if not exclude[ch] and ev[ch] and ev[ch] > max_E_en then
          local stripnum = (ch-101)%16
          max_E_en = ev[ch]
          max_E_strip = stripnum
        end
      end

      if max_E_en > 0 then
        orruba_monitors.sidar_en_vs_strip.hist:Fill(max_E_strip, max_E_en)

        local max_dE_en = 0
        for ch = first_ch-100, first_ch-100+16 do
          if not exclude[ch] and ev[ch] and ev[ch] > max_dE_en then
            max_dE_en = ev[ch]
          end
        end

        if max_E_en > 0 and max_dE_en > 0 then
          orruba_monitors.sidar_dE_vs_E.hist:Fill(max_E_en, max_dE_en)

          if proton_cut and proton_cut:IsInside(max_E_en, max_dE_en) == 1 then

            validate_SIDAR_proton_gate = true
            orruba_monitors.sidar_en_vs_strip_protons.hist:Fill(max_E_strip, max_E_en)
          end
        end
      end
    end
  end,
}

----------------------- Monitors ---------------------------

function SetupStandardMonitors()
  if not orruba_applycal then
    AddMonitor("En vs. Ch", {name = "h_monitor", title = "Monitor", xmin = 0, xmax = 899, nbinsx = 899, ymin = 0, ymax = 4096, nbinsy = 4096}, fillfns.FillChVsValue)
  else
    local cfile = TFile("/user/e16025/luaXroot/user/pid_cuts.root", "read")
    proton_cut = cfile:GetObject("TCutG", "maybeprotons")
    cfile:Close()

    AddMonitor("En vs. Ch", {name = "h_monitor", title = "Monitor", xmin = 0, xmax = 899, nbinsx = 899, ymin = 0, ymax = 10, nbinsy = 1000}, fillfns.FillChVsValue)
    AddMonitor("SIDAR En vs. Strip", {name = "sidar_en_vs_strip", title = "SIDAR Energy vs. Strip#", xmin = 0, xmax = 16, nbinsx = 16, ymin = 0, ymax = 10, nbinsy = 1000}, fillfns.FillSIDARGraphs)
    AddMonitor("SIDAR En vs. Strip Gate Protons", {name = "sidar_en_vs_strip_protons", title = "SIDAR Energy vs. Strip# gate protons (maybe?)", xmin = 0, xmax = 16, nbinsx = 16, ymin = 0, ymax = 10, nbinsy = 1000}, function() end)
    AddMonitor("SIDAR dE vs. E", {name = "sidar_dE_vs_E", title = "SIDAR dE vs. E", xmin = 0, xmax = 15, nbinsx = 1500, ymin = 0, ymax = 15, nbinsy = 1500}, function() end)
  end

  for detid=1, 12 do
    for strip=1, 4 do
      local hname, htitle, detkey, halias

--      local hname = string.format("SX3_U%d_resistive_%d", detid, strip)
--      local htitle = string.format("SuperX3 U%d left vs. right strip %d", detid, strip)
--      local detkey = string.format("SuperX3 U%d", detid)
--      local halias = string.format("SX3 U%d resistive f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=10, nbinsx=1000, ymin=0, ymax=10, nbinsy=1000}, fillfns.FillSX3LeftVsRight(detkey, strip))

      hname = string.format("SX3_U%d_en_%d", detid, strip)
      htitle = string.format("SuperX3 U%d front strip %d", detid, strip)
      detkey = string.format("SuperX3 U%d", detid)
      halias = string.format("SX3 U%d en f%d", detid, strip)
      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=15, nbinsx=1500}, fillfns.FillResistiveFrontSum(detkey, strip))

--      hname = string.format("SX3_U%d_position_%d", detid, strip)
--      htitle = string.format("SuperX3 U%d position strip %d", detid, strip)
--      halias = string.format("SX3 U%d pos f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=10, nbinsy=1000}, fillfns.FillSX3RelativePosition(detkey, strip))

--      hname = string.format("SX3_U%d_position_%d_enback", detid, strip)
--      htitle = string.format("SuperX3 U%d position strip %d using backside energy", detid, strip)
--      halias = string.format("SX3 U%d pos f%d en back", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=4096, nbinsy=2048}, fillfns.FillSX3RelativePosition(detkey, strip, true))

--      hname = string.format("SX3_D%d_resistive_%d", detid, strip)
--      htitle = string.format("SuperX3 D%d left vs. right strip %d", detid, strip)
--      detkey = string.format("SuperX3 D%d", detid)
--      halias = string.format("SX3 D%d resistive f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=4096, nbinsx=512, ymin=0, ymax=4096, nbinsy=512}, fillfns.FillSX3LeftVsRight(detkey, strip))

      hname = string.format("SX3_D%d_en_%d", detid, strip)
      htitle = string.format("SuperX3 D%d front strip %d", detid, strip)
      detkey = string.format("SuperX3 D%d", detid)
      halias = string.format("SX3 D%d en f%d", detid, strip)
      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=15, nbinsx=1500}, fillfns.FillResistiveFrontSum(detkey, strip))

--      hname = string.format("SX3_D%d_position_%d", detid, strip)
--      htitle = string.format("SuperX3 D%d position strip %d", detid, strip)
--      halias = string.format("SX3 D%d pos f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=4096, nbinsy=2048}, fillfns.FillSX3RelativePosition(detkey, strip))

--      hname = string.format("SX3_D%d_position_%d_enback", detid, strip)
--      htitle = string.format("SuperX3 D%d position strip %d using backside energy", detid, strip)
--      halias = string.format("SX3 D%d pos f%d en back", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=4096, nbinsy=2048}, fillfns.FillSX3RelativePosition(detkey, strip, true))
    end
  end

  for strip=1,4 do
    hname = string.format("Elastics_BOTTOMLEFT_en_%d", strip)
    htitle = string.format("Elastics Bottom Left front strip %d", strip)
    detkey = string.format("Elastics BOTTOMLEFT")
    halias = string.format("Elastics Bottom Left en f%d", strip)
    AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=15, nbinsx=1500}, fillfns.FillResistiveFrontSum(detkey, strip))

    hname = string.format("Elastics_BOTTOMRIGHT_en_%d", strip)
    htitle = string.format("Elastics Bottom Right front strip %d", strip)
    detkey = string.format("Elastics BOTTOMRIGHT")
    halias = string.format("Elastics Bottom Right en f%d", strip)
    AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=15, nbinsx=1500}, fillfns.FillResistiveFrontSum(detkey, strip))

    hname = string.format("Elastics_TOPRIGHT_en_%d", strip)
    htitle = string.format("Elastics Top Right front strip %d", strip)
    detkey = string.format("Elastics TOPRIGHT")
    halias = string.format("Elastics Top Right en f%d", strip)
    AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=15, nbinsx=1500}, fillfns.FillResistiveFrontSum(detkey, strip))
  end

--  AddMonitor("MCP1 X", {name = "MCP1_X_MBD4", title = "MCP1 X Position MBD4", xmin = 0, xmax = 1024, nbinsx = 512}, fillfns.FillMCP("MCP 1 MBD4", "x"))
--  AddMonitor("MCP1 Y", {name = "MCP1_Y_MBD4", title = "MCP1 Y Position MBD4", xmin = 0, xmax = 1024, nbinsx = 512}, fillfns.FillMCP("MCP 1 MBD4", "y"))
--  AddMonitor("MCP2 X", {name = "MCP2_X_MBD4", title = "MCP2 X Position MBD4", xmin = 0, xmax = 4096, nbinsx = 2048}, fillfns.FillMCP("MCP 2 MBD4", "x"))
--  AddMonitor("MCP2 Y", {name = "MCP2_Y_MBD4", title = "MCP2 Y Position MBD4", xmin = 0, xmax = 4096, nbinsx = 2048}, fillfns.FillMCP("MCP 2 MBD4", "y"))

--  AddMonitor("MCP1 X vs. Y", {name = "MCP1_XvsY_MDB4", title = "MCP1 X vs. Y MBD4", xmin = -1, xmax = 1, nbinsx = 1500, ymin = -1, ymax = 1, nbinsy = 1500}, fillfns.FillMCP("MCP 1 MBD4", "x vs. y"))
--  AddMonitor("MCP2 X vs. Y", {name = "MCP2_XvsY_MDB4", title = "MCP2 X vs. Y MBD4", xmin = -1, xmax = 1, nbinsx = 1000, ymin = -1, ymax = 1, nbinsy = 1000}, fillfns.FillMCP("MCP 2 MBD4", "x vs. y"))

--  AddMonitor("MCP1 X QDC", {name = "MCP1_X_QDC", title = "MCP1 X Position with QDC", xmin = 0, xmax = 1024, nbinsx = 512}, fillfns.FillMCP("MCP 1 QDC", "x"))
--  AddMonitor("MCP1 Y QDC", {name = "MCP1_Y_QDC", title = "MCP1 Y Position with QDC", xmin = 0, xmax = 1024, nbinsx = 512}, fillfns.FillMCP("MCP 1 QDC", "y"))
--  AddMonitor("MCP2 X QDC", {name = "MCP2_X_QDC", title = "MCP2 X Position with QDC", xmin = 0, xmax = 4096, nbinsx = 2048}, fillfns.FillMCP("MCP 2 QDC", "x"))
--  AddMonitor("MCP2 Y QDC", {name = "MCP2_Y_QDC", title = "MCP2 Y Position with QDC", xmin = 0, xmax = 4096, nbinsx = 2048}, fillfns.FillMCP("MCP 2 QDC", "y"))

--  AddMonitor("MCP1 X vs. Y QDC", {name = "MCP1_XvsY_QDC", title = "MCP1 X vs. Y with QDC", xmin = -1, xmax = 1, nbinsx = 1500, ymin = -1, ymax = 1, nbinsy = 1500}, fillfns.FillMCP("MCP 1 QDC", "x vs. y"))
--  AddMonitor("MCP2 X vs. Y QDC", {name = "MCP2_XvsY_QDC", title = "MCP2 X vs. Y with QDC", xmin = -1, xmax = 1, nbinsx = 1000, ymin = -1, ymax = 1, nbinsy = 1000}, fillfns.FillMCP("MCP 2 QDC", "x vs. y"))
end

return fillfns