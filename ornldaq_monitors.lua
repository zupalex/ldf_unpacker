orruba_monitors = {}

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


local fillfns = {
  FillChVsValue = function(hist, ev)
    for k, v in pairs(ev) do
      hist:Fill(k, en)
    end
  end,

  FillIfValidChannel = function(channel)
    return function(hist, ev)
      if ev[channel] then
        hist:Fill(ev[channel])
      end
    end
  end,

  FillIfValidChannels = function(chlist)
    return function(hist, ev)
      for _, ch in ipairs(chlist) do
        if ev[ch] then 
          hist:Fill(ev[ch]) 
        end
      end
    end
  end,

  FillCh1IfCh2 = function(ch1, ch2)
    return function(hist, ev)
      if ev[ch1] and ev[ch2] then
        hist:Fill(ev[ch1])
      end
    end
  end,

  FillCh1IfChlist = function(ch1, chlist, getall)
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
}

return fillfns