orruba_applycal = false

orruba_monitors = {}
haliases = {}

local mapping = require("ldf_unpacker/se84_mapping")
local calib = require("ldf_unpacker/se84_calibration")

local ch_cal, det_cal = calib.readcal()

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

  local GetEn

  if orruba_applycal and det_cal[detKey1] and det_cal[detKey2] then
    GetEn = function(ev)
      return ev[ch_right] and det_cal[detKey1]:calibrate(ev[ch_right], ev) or ev[ch_right], ev[ch_left] and det_cal[detKey2]:calibrate(ev[ch_left], ev) or ev[ch_left]
    end
  else
    GetEn = function(ev)
      return ev[ch_right], ev[ch_left]
    end
  end

  local GetEnSum

  if not useback then
    GetEnSum = function(ev)
      local en_right, en_left = GetEn(ev)
      local en_sum = en_right+en_left
      return en_sum, en_sum
    end
  else
    local backStrips = mapping.getchannels(detector, "b")
    GetEnSum = function(ev)
      local maxBack = 0
      for _, s in ipairs(backStrips) do
        local en_ = ev[s]
        if en_ and en_ > maxBack then
          maxBack = orruba_applycal and ch_cal[s] and ch_cal[s]:calibrate(en_, ev) or en_
        end
      end

      local en_right, en_left = GetEn(ev)
      local en_sum = en_right+en_left

      return en_sum, maxBack
    end
  end

  local GetEnDiff = function(ev)
    return ev[ch_left] - ev[ch_right]
  end

  return ch_left, ch_right, GetEnSum, GetEnDiff
end

proton_in_orruba = false

local fillfns = {
  FillChVsValue = function(hist, ev)
    for k, v in pairs(ev) do
      local en = orruba_applycal and (ch_cal[k] and ch_cal[k].calibrate and ch_cal[k]:calibrate(v, ev) or nil) or v
      if en then
        hist:Fill(k, en)

        if orruba_applycal and en > 4 and ((k >= 101 and k < 199) or (k >= 301 and k < 399 ))then
          proton_in_orruba = true
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

    if orruba_applycal and det_cal[detKey1] and det_cal[detKey2] then
      GetEn = function(ev)
        return ev[ch1] and det_cal[detKey1]:calibrate(ev[ch1], ev) or nil, ev[ch2] and det_cal[detKey2]:calibrate(ev[ch2], ev) or nil
      end
    else
      GetEn = function(ev)
        return ev[ch1], ev[ch2]
      end
    end

    return function(hist, ev)
      local en_right, en_left = GetEn(ev)

      if en_left and en_right then 
        hist:Fill(en_left, en_right)
      end
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
}

----------------------- Monitors ---------------------------

function SetupStandardMonitors()
  AddMonitor("En vs. Ch", {name = "h_monitor", title = "Monitor", xmin = 0, xmax = 899, nbinsx = 899, ymin = 0, ymax = 4096, nbinsy = 4096}, fillfns.FillChVsValue)

  for detid=1, 12 do
    for strip=1, 4 do
      local hname = string.format("SX3_U%d_resistive_%d", detid, strip)
      local htitle = string.format("SuperX3 U%d front strip %d", detid, strip)
      local detkey = string.format("SuperX3 U%d", detid)
      local halias = string.format("SX3 U%d en f%d", detid, strip)
      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=10, nbinsx=1000, ymin=0, ymax=10, nbinsy=1000}, fillfns.FillSX3LeftVsRight(detkey, strip))

--      hname = string.format("SX3_U%d_position_%d", detid, strip)
--      htitle = string.format("SuperX3 U%d position strip %d", detid, strip)
--      halias = string.format("SX3 U%d pos f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=10, nbinsy=1000}, fillfns.FillSX3RelativePosition(detkey, strip))

--      hname = string.format("SX3_U%d_position_%d_enback", detid, strip)
--      htitle = string.format("SuperX3 U%d position strip %d using backside energy", detid, strip)
--      halias = string.format("SX3 U%d pos f%d en back", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=-1, xmax=1, nbinsx=200, ymin=0, ymax=4096, nbinsy=2048}, fillfns.FillSX3RelativePosition(detkey, strip, true))

--      hname = string.format("SX3_D%d_resistive_%d", detid, strip)
--      htitle = string.format("SuperX3 D%d front strip %d", detid, strip)
--      detkey = string.format("SuperX3 D%d", detid)
--      halias = string.format("SX3 D%d en f%d", detid, strip)
--      AddMonitor(halias, {name = hname, title = htitle, xmin=0, xmax=4096, nbinsx=512, ymin=0, ymax=4096, nbinsy=512}, fillfns.FillSX3LeftVsRight(detkey, strip))

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