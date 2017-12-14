require("ldf_unpacker/ldf_onlinereader")

local monitoring = require("ldf_unpacker/ornldaq_monitors")
local mapping = require("ldf_unpacker/se84_mapping")
local calib = require("ldf_unpacker/se84_calibration")

--det_params, ch_params = calib.readcal()

local function UpdateCalibFile(file, buffer_file, det_type, additional_matches, not_any_of)
  local line = file:read("l")

  while line do
    local not_updated = true

    print("checking", line)

    for det, strips in pairs(det_type) do
      if line:find(det) then
        if #additional_matches == 0 and #not_any_of == 0 then
          not_updated = false
          break
        elseif #additional_matches == 0 and #not_any_of > 0 then
          for i, v in ipairs(not_any_of) do
            if line:find(v) then
              break
            end
          end

          not_updated = false
        else
          for i, v in ipairs(additional_matches) do
            if not line:find(v) then
              break
            elseif i == #additional_matches and line:find(v) then
              not_updated = false
            end

            if not not_updated then break end
          end

          if not not_updated and (not_any_of and #not_any_of > 0) then
            for i, v in ipairs(not_any_of) do
              if line:find(v) then
                not_updated = true
                break
              end
            end
          end
        end
      end
    end

    if not_updated then
      print(line, "not updated... copying previous content...")
      buffer_file:write(line, "\n")
    else
      print(line, "has been updated... skipping content...")
    end

    line = file:read("l")

    while line do
      local pIter = line:gmatch("-?%a+%d*")

      local dtype, dId = pIter(), pIter()

      if mapping.det_prop[dtype] then
        break
      elseif not_updated then
        buffer_file:write(line, "\n")
      end

      line = file:read("l")
    end
  end
end

local alpha_energies = { 5.157, 5.486, 5.805 }

local detectors = {
--  {type = "SIDAR", id = "dE1" },
--  {type = "SIDAR", id = "dE2" },
--  {type = "SIDAR", id = "dE3" },
--  {type = "SIDAR", id = "dE4" },
--  {type = "SIDAR", id = "dE5" },
  {type = "SIDAR", id = "dE6" },

--  {type = "SIDAR", id = "E1" },
--  {type = "SIDAR", id = "E2" },
--  {type = "SIDAR", id = "E3" },
--  {type = "SIDAR", id = "E4" },
--  {type = "SIDAR", id = "E5" },
--  {type = "SIDAR", id = "E6" },

--  {type = "BB10", id = "1" },
--  {type = "BB10", id = "2" },
--  {type = "BB10", id = "3" },
--  {type = "BB10", id = "4" },
--  {type = "BB10", id = "5" },
--  {type = "BB10", id = "6" },
--  {type = "BB10", id = "7" },
--  {type = "BB10", id = "8" },
--  {type = "BB10", id = "9" },
--  {type = "BB10", id = "10"},
--  {type = "BB10", id = "11"},
--  {type = "BB10", id = "12"},

--  {type = "X3", id = "1" },
--  {type = "X3", id = "2" },
--  {type = "X3", id = "3" },
--  {type = "X3", id = "4" },
--  {type = "X3", id = "5" },
--  {type = "X3", id = "6" },
--  {type = "X3", id = "7" },
--  {type = "X3", id = "8" },
--  {type = "X3", id = "9" },
--  {type = "X3", id = "10"},
--  {type = "X3", id = "11"},
--  {type = "X3", id = "12"},
}

local function GetMaxPeak(amps)
  local peaknum, max = -1, 0

  for i, v in ipairs(amps) do
    if v == 0 then print("amp is 0?") end
    if v > max then
      max = v
      peaknum = i
    end
  end

  return peaknum
end

local function RemoveUselessPeaks(peaks)
  local keepx = newtable()
  local keepy = newtable()

  if #peaks.x > 3 then
    local maxpos = GetMaxPeak(peaks.y)

    for i, v in ipairs(peaks.x) do
      if v < peaks.x[maxpos] then
        table.remove(peaks.x, i)
        table.remove(peaks.y, i)
        if i < maxpos then maxpos = maxpos-1 end
      end
    end

    keepx:insert(peaks.x[maxpos])
    keepy:insert(peaks.y[maxpos])

    table.remove(peaks.x, maxpos)
    table.remove(peaks.y, maxpos)

    while #keepx < 3 do
      maxpos = GetMaxPeak(peaks.y)

      if maxpos == -1 then break end

      for i, v in ipairs(peaks.x) do
        if i ~= maxpos then
          if math.abs(v-peaks.x[maxpos]) < 30 then
            table.remove(peaks.x, i)
            table.remove(peaks.y, i)
            if i < maxpos then maxpos = maxpos-1 end
          end
        end
      end

      keepx:insert(peaks.x[maxpos])
      keepy:insert(peaks.y[maxpos])

      table.remove(peaks.x, maxpos)
      table.remove(peaks.y, maxpos)
    end
  else
    keepx = peaks.x
    keepy = peaks.y
  end

  return keepx, keepy
end

local function gaussf(x, amp, mean, sigma)
  return amp * math.exp( - ((x-mean)^2)/(sigma^2))
end

function getfitfunc(npeaks)
  return function(x, sigma, ...)
    local res = 0
    local otherArgs = table.pack(...)
    local cur_idx = 1

    for i=1, npeaks do
      res = res + gaussf(x, otherArgs[cur_idx], otherArgs[cur_idx+1], sigma)
      cur_idx = cur_idx+2
    end

    return res
  end    
end

local function DoPeakSearchAndFit(spec, hist, det_type, det_id, stripnum, npeaks_force)
  if hist:Integral() > 100 then
    hist:SetRangeUserX(400, 5000)
    hist:Draw()
    spec:Search(hist:GetName(), 4, "", 0.02)

    local np = spec:GetNPeaks()
    local xpos = spec:GetPositionX()
    local ypos = spec:GetPositionY()

    if np >= 3 then
      local usefulPeaks = table.pack(RemoveUselessPeaks({x=spec:GetPositionX(), y=spec:GetPositionY()}))

      local effective_npeaks = npeaks_force ~= nil and npeaks_force or np

      local fitfunc = TF1("fitfunc"..tostring(i), getfitfunc(effective_npeaks), 1000, 5000, 2*effective_npeaks+1)

      fitfunc:SetParameter(0, 2)

      local spread = usefulPeaks[1][3] - usefulPeaks[1][1]

      if npeaks_force then
        for pnum=1, 6 do
          if pnum%2 == 0 then
            fitfunc:SetParameter(2*(pnum-1)+1, usefulPeaks[2][pnum/2])
            fitfunc:SetParameter(2*(pnum-1)+2, usefulPeaks[1][pnum/2])
          else
            fitfunc:SetParameter(2*(pnum-1)+1, usefulPeaks[2][math.floor(pnum/2)+1]*0.2)
            fitfunc:SetParameter(2*(pnum-1)+2, usefulPeaks[1][math.floor(pnum/2)+1]-(spread*0.05))
          end
        end

        local pars = fitfunc:GetParameters()
      else
        for pnum=1, np do
          fitfunc:SetParameter(2*(pnum-1)+1, ypos[pnum])
          fitfunc:SetParameter(2*(pnum-1)+2, xpos[pnum])
        end
      end

      hist:SetRangeUserX(usefulPeaks[1][1] - 100, usefulPeaks[1][3] + 100)

      hist:Fit({fn=fitfunc, opts="QM"})

      print("Sigma for ", det_type, det_id, "strip", stripnum, "=>", fitfunc:GetParameter(0))

      return usefulPeaks[1]
    else
      return {}
    end
  else 
    return {}
  end
end

function DrawGraphAndFit(peaks, graph, fitfunc)
  local fitRes = {}

  if #peaks > 0 then
    for n, peak in ipairs(peaks) do
      graph:SetPoint(n, peak, alpha_energies[n])
    end

    graph:Draw("AP")
    graph:Fit({fn=fitfunc, opts="RQM"})
    fitRes = fitfunc:GetParameters()
  end

  return fitRes
end

function CalibrateStandardStrips(input, savetoroot)
  local root_source = false

  local runname, rootfile

  if input:find(".root") then
    root_source = true
    runname = input:sub(input:find("cal_hists_")+10, input:len()-5)
  else
    runname = input:sub(input:find_last_occurence("/")+1, input:len()-4)
  end

  local nstrips = {}

  local spec=TSpectrum(10)

  if not root_source and savetoroot then
    rootfile = TFile("cal_hists_"..runname..".root", "update")
  end

  if not root_source then
    StartMonitoring(input, nil, true)

    local ch_vs_en=GetObject("TH2D", "h_monitor")

    for i, det in ipairs(detectors) do
      for j, ch in ipairs(mapping.getchannels(det.type.." "..det.id, det.side)) do
        local stripid = (i-1)*4+j
        nstrips[stripid] = ch_vs_en:ProjectY(ch, ch):Clone()
        nstrips[stripid]:SetName(tostring(det.type).."_"..tostring(det.id).."_strip_"..(det.side and det.side or "")..tostring(j))
        nstrips[stripid]:SetTitle(tostring(det.type).." "..tostring(det.id).." Strip "..(det.side == "f" and "front" or (det.side == "b" and "back" or ""))..tostring(j))
        nstrips[stripid].id = det.id
        nstrips[stripid].stripnum = j
        nstrips[stripid].det_type = det.type
      end
    end

    if not root_source and savetoroot then
      rootfile:Overwrite()
      return
    end
  else
    local input_root = TFile(input, "read")

    for i, det in ipairs(detectors) do
      for j, ch in ipairs(mapping.getchannels(det.type.." "..det.id, det.side)) do
        local stripid = (i-1)*4+j
        nstrips[stripid] = input_root:GetObject("TH1", tostring(det.type).."_"..tostring(det.id).."_strip_"..(det.side and det.side or "")..tostring(j))
        nstrips[stripid].id = det.id
        nstrips[stripid].stripnum = j
        nstrips[stripid].det_type = det.type
      end
    end
  end

  local peaks_pos = {}

  for i, v in ipairs(nstrips) do
    if peaks_pos[v.det_type.." "..v.id] == nil then
      peaks_pos[v.det_type.." "..v.id] = {}
      peaks_pos[v.det_type.." "..v.id].det_type = v.det_type
    end

    v:Draw()
    theApp:Update()

    v:Rebin(4)

    peaks_pos[v.det_type.." "..v.id][v.stripnum] = DoPeakSearchAndFit(spec, v, v.det_type, v.id, v.stripnum, 6)
  end

  if type(input) == "table" then input = input[1] end

  local prev_cals = io.open("cal_params_"..runname..".txt", "r")
  local output = io.open(".tempcalpars.txt", "w")

  local gr = TGraph(3)
  local fitfunc = TF1("fitfunc", function(x, a, b) return a*x+b end, 5, 6, 2)

  if prev_cals then
    UpdateCalibFile(prev_cals, output, peaks_pos, {}, {"back side"})
  end

  for det, strips in pairs(peaks_pos) do
    output:write(det.."\n")
    for strip, peaks in ipairs(strips) do
      local fitRes = DrawGraphAndFit(peaks, gr, fitfunc)
      output:write(string.format("%-6d %f %f\n", strip, fitRes[1] or 0.0, fitRes[2] or 0.0))
    end
  end

  output:close()

  os.remove("cal_params_"..runname..".txt")

  os.rename(".tempcalpars.txt", "cal_params_"..runname..".txt")
end


------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

local sx3_back = {
--  {type = "SuperX3", id = "U1" , side = "back" },
--  {type = "SuperX3", id = "U2" , side = "back" },
--  {type = "SuperX3", id = "U3" , side = "back" },
--  {type = "SuperX3", id = "U4" , side = "back" },
--  {type = "SuperX3", id = "U5" , side = "back" },
--  {type = "SuperX3", id = "U6" , side = "back" },
--  {type = "SuperX3", id = "U7" , side = "back" },
--  {type = "SuperX3", id = "U8" , side = "back" },
--  {type = "SuperX3", id = "U9" , side = "back" },
--  {type = "SuperX3", id = "U10", side = "back" },
--  {type = "SuperX3", id = "U11", side = "back" },
--  {type = "SuperX3", id = "U12", side = "back" },

--  {type = "SuperX3", id = "D1" , side = "back" },
--  {type = "SuperX3", id = "D2" , side = "back" },
--  {type = "SuperX3", id = "D3" , side = "back" },
--  {type = "SuperX3", id = "D4" , side = "back" },
--  {type = "SuperX3", id = "D5" , side = "back" },
--  {type = "SuperX3", id = "D6" , side = "back" },
--  {type = "SuperX3", id = "D7" , side = "back" },
--  {type = "SuperX3", id = "D8" , side = "back" },
--  {type = "SuperX3", id = "D9" , side = "back" },
--  {type = "SuperX3", id = "D10", side = "back" },
--  {type = "SuperX3", id = "D11", side = "back" },
--  {type = "SuperX3", id = "D12", side = "back" },
}

function CalibrateSX3Backside(input, savetoroot)
  local root_source = false
  local inputfile, rootfile

  local slashPos = input:find_last_occurence("/") or 0
  local runname

  if input:find(".root") then
    root_source = true
    runname = input:sub(input:find("cal_hists_")+10, input:len()-5)
  else
    runname = input:sub(input:find_last_occurence("/")+1, input:len()-4)
  end

  if root_source then
    inputfile = TFile(input, "read")
  end

  local hists = newtable()

  local front_div = { {1, 2}, {3, 4}, {5, 6}, {7, 8} }

  if not root_source and savetoroot then
    rootfile = TFile("cal_hists_"..runname..".root", "update")
  end

  for i, det in ipairs(sx3_back) do
    local det_strips = mapping.getchannels(det.type.." "..det.id, det.side)

    for j=1,4 do
      for _, fdiv in ipairs(front_div) do
        local hname = tostring(det.type).."_"..tostring(det.id).."_strip_b"..tostring(j).."_if_f"..tostring(fdiv[1])..tostring(fdiv[2])

        if not root_source then
          AddMonitor({name = hname, 
              title =  tostring(det.type).." "..tostring(det.id).." Energy backside strip "..tostring(j).." if front "..tostring(fdiv[1]).." or "..tostring(fdiv[2]), 
              xmin = 0, xmax = 4096, nbinsx = 4096}, 
            monitoring.FillCh1IfChlist("SuperX3 "..tostring(det.id).." b"..tostring(j), 
              {"SuperX3 "..tostring(det.id).." f"..tostring(fdiv[1]), "SuperX3 "..tostring(det.id).." f"..tostring(fdiv[2])}, true))

          hists:insert(orruba_monitors[hname].hist)

          orruba_monitors[hname].hist.det_type = det.type
          orruba_monitors[hname].hist.id = det.id
          orruba_monitors[hname].hist.stripnum = j
          orruba_monitors[hname].hist.front_strips = fdiv
        else
          local nhist = inputfile:GetObject("TH1", hname)
          print("attempt to retrieve", hname, nhist)
          nhist.det_type = det.type
          nhist.id = det.id
          nhist.front_strips = fdiv
          nhist.stripnum = j

          hists:insert(nhist)
        end
      end
    end
  end

  if not root_source then
    StartMonitoring(input, nil, true)
  end

  if not root_source and savetoroot then
    rootfile:Overwrite()

    rootfile:Close()

    return
  end

  local spec=TSpectrum(10)

  local peaks_pos = {}

  for i, v in ipairs(hists) do
    local detKey = v.det_type.." "..v.id

    if peaks_pos[detKey] == nil then
      peaks_pos[detKey] = {}
      peaks_pos[detKey].det_type = v.det_type
      peaks_pos[detKey].id = v.id
    end

    if peaks_pos[detKey][v.stripnum] == nil then
      peaks_pos[detKey][v.stripnum] = {}
      peaks_pos[detKey][v.stripnum].stripnum = v.stripnum
    end

    peaks_pos[detKey][v.stripnum][math.floor(v.front_strips[1]/2) + 1] = DoPeakSearchAndFit(spec, v, v.det_type, v.id, v.stripnum, 6)

    peaks_pos[detKey][v.stripnum][math.floor(v.front_strips[1]/2) + 1].front_strips = v.front_strips
  end

  if type(input) == "table" then input = input[1] end

  local prev_cals = io.open("cal_params_"..runname..".txt", "r")
  local output = io.open(".tempcalpars.txt", "w")

  local gr = TGraph(3)
  local fitfunc = TF1("fitfunc", function(x, a, b) return a*x+b end, 5, 6, 2)

  if prev_cals then
    UpdateCalibFile(prev_cals, output, peaks_pos, {"back side"})
  end

  for det, strips in pairs(peaks_pos) do   
    output:write(det.." back side\n")
    for bstrip, fronts in ipairs(strips) do
      for fstrip, peaks in ipairs(fronts) do
        local fitRes = DrawGraphAndFit(peaks, gr, fitfunc)
        output:write(string.format("%-6d %-6d %-6d %8.6f    %f\n", bstrip, peaks.front_strips[1], peaks.front_strips[2], fitRes[1] or 0.0, fitRes[2] or 0.0))
      end
    end
  end

  output:close()

  os.remove("cal_params_"..runname..".txt")

  os.rename(".tempcalpars.txt", "cal_params_"..runname..".txt")
end

------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

local resistives = {
  { type = "SuperX3", id = "U1" , side = "front" },
--  { type = "SuperX3", id = "U2" , side = "front" },
--  { type = "SuperX3", id = "U3" , side = "front" },
--  { type = "SuperX3", id = "U4" , side = "front" },
--  { type = "SuperX3", id = "U5" , side = "front" },
--  { type = "SuperX3", id = "U6" , side = "front" },
--  { type = "SuperX3", id = "U7" , side = "front" },
--  { type = "SuperX3", id = "U8" , side = "front" },
--  { type = "SuperX3", id = "U9" , side = "front" },
--  { type = "SuperX3", id = "U10", side = "front" },
--  { type = "SuperX3", id = "U11", side = "front" },
--  { type = "SuperX3", id = "U12", side = "front" },

--  { type = "SuperX3", id = "D1" , side = "front" },
--  { type = "SuperX3", id = "D2" , side = "front" },
--  { type = "SuperX3", id = "D3" , side = "front" },
--  { type = "SuperX3", id = "D4" , side = "front" },
--  { type = "SuperX3", id = "D5" , side = "front" },
--  { type = "SuperX3", id = "D6" , side = "front" },
--  { type = "SuperX3", id = "D7" , side = "front" },
--  { type = "SuperX3", id = "D8" , side = "front" },
--  { type = "SuperX3", id = "D9" , side = "front" },
--  { type = "SuperX3", id = "D10", side = "front" },
--  { type = "SuperX3", id = "D11", side = "front" },
--  { type = "SuperX3", id = "D12", side = "front" },
}

function ProduceResistiveHistograms(input, graph_type)
  local en_his, pos_his = false, false

  if graph_type == nil or graph_type == "Energy" or graph_type == "energy" or graph_type == "En" or graph_type == "en" then
    en_his = true
  elseif graph_type == "Position" or graph_type == "position" or graph_type == "Pos" or graph_type == "pos" then
    pos_his = true
  else
    return
  end

  local hists = newtable()

  local runname = input:sub(input:find_last_occurence("/")+1, input:len()-4)

  local outf = TFile("resistive_"..(en_his and "energy_" or "position_").."grahps_run_"..runname..".root", "update")

  for i, det in ipairs(resistives) do
    local channels = mapping.getchannels(det.type.." "..det.id, det.side)
    local strip_order = mapping.det_prop[det.type][det.side or "front"].order

    local first_ch = math.min(table.unpack(strip_order or channels))

    for j=1, #channels/2 do
      local chnum = strip_order and strip_order[2*(j-1)+1] or 2*(j-1)+1

      local hname = tostring(det.type).."_"..tostring(det.id).."_strip"..tostring(j)
      local detKey = tostring(det.type).." "..tostring(det.id)

      if en_his then
        AddMonitor({name = hname, 
            title =  detKey.." Energy Left vs. Right - Resistive Strip "..tostring(j), 
            xmin = 0, xmax = 4096, nbinsx = 1024, ymin = 0, ymax = 4096, nbinsy = 1024}, 
          monitoring.FillSX3LeftVsRight(detKey, j))
        hists:insert(orruba_monitors[hname].hist)
      elseif pos_his then
        AddMonitor({name = hname, 
            title = tostring(det.type).." "..tostring(det.id).." Total Energy vs. Relative Position - Resistive Strip "..tostring(j), 
            xmin = -1, xmax = 1, nbinsx = 400, ymin = 0, ymax = 4096, nbinsy = 1024}, 
          monitoring.FillSX3RelativePosition(detKey, j))
        hists:insert(orruba_monitors[hname].hist)
      end
    end
  end

  StartMonitoring(input, nil, true)

  outf:cd()

  outf:Overwrite()

  outf:Close()
end