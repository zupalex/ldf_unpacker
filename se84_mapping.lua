local detectors_properties = {
  SIDAR = { front = {strips = 16}},

  BB10 = { front = {strips = 8}},

  SuperX3 = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7} }, back = {strips = 4} },

  X3 = { front = {strips = 1}},

  Elastics = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7}}, back = {strips = 1} }
}

local mapping = {
  SIDAR = {
    dE1 = { front = { ch=1 } },
    dE2 = { front = { ch=7 } },
    dE3 = { front = { ch=3 } },
    dE4 = { front = { ch=9 } },
    dE5 = { front = { ch=5 } },
    dE6 = { front = { ch=1 } },

    E1 = { front = { ch=01 } },
    E2 = { front = { ch=17 } },
    E3 = { front = { ch=33 } },
    E4 = { front = { ch=49 } },
    E5 = { front = { ch=65 } },
    E6 = { front = { ch=81 } },
  },

  BB10 = {
    [1] =  { front = { ch=01 } },
    [2] =  { front = { ch=09 } },
    [3] =  { front = { ch=17 } },
    [4] =  { front = { ch=25 } },
    [5] =  { front = { ch=33 } },
    [6] =  { front = { ch=41 } },
    [7] =  { front = { ch=49 } },
    [8] =  { front = { ch=57 } },
    [9] =  { front = { ch=65 } },
    [10] = { front = { ch=73 } },
    [11] = { front = { ch=81 } },
    [12] = { front = { ch=89 } },
  },

  SuperX3 = {
    U1 =  { front = { ch=01 } , back = { ch=01 } },
    U2 =  { front = { ch=09 } , back = { ch=05 } },
    U3 =  { front = { ch=17 } , back = { ch=09 } },
    U4 =  { front = { ch=25 } , back = { ch=13 } },
    U5 =  { front = { ch=33 } , back = { ch=33 } },
    U6 =  { front = { ch=41 } , back = { ch=37 } },
    U7 =  { front = { ch=49 } , back = { ch=17 } },
    U8 =  { front = { ch=57 } , back = { ch=21 } },
    U9 =  { front = { ch=65 } , back = { ch=25 } },
    U10 = { front = { ch=73 } , back = { ch=29 } },
    U11 = { front = { ch=81 } , back = { ch=41 } },
    U12 = { front = { ch=89 } , back = { ch=45 } },

    D1 =  { front = { ch=01 } , back = { ch=49 } },
    D2 =  { front = { ch=09 } , back = { ch=53 } },
    D3 =  { front = { ch=17 } , back = { ch=57 } },
    D4 =  { front = { ch=25 } , back = { ch=61 } },
    D5 =  { front = { ch=33 } , back = { ch=81 } },
    D6 =  { front = { ch=41 } , back = { ch=85 } },
    D7 =  { front = { ch=49 } , back = { ch=65 } },
    D8 =  { front = { ch=57 } , back = { ch=69 } },
    D9 =  { front = { ch=65 } , back = { ch=73 } },
    D10 = { front = { ch=73 } , back = { ch=77 } },
    D11 = { front = { ch=81 } , back = { ch=89 } },
    D12 = { front = { ch=89 } , back = { ch=93 } },
  },

  X3 = {
    [1]  =  { front = { ch=04 } },
    [2]  =  { front = { ch=03 } },
    [3]  =  { front = { ch=02 } },
    [4]  =  { front = { ch=01 } },
    [5]  =  { front = { ch=06 } },
    [6]  =  { front = { ch=05 } },
    [7]  =  { front = { ch=12 } },
    [8]  =  { front = { ch=11 } },
    [9]  =  { front = { ch=10 } },
    [10] =  { front = { ch=09 } },
    [11] =  { front = { ch=14 } },
    [12] =  { front = { ch=13 } },
  },

  Elastics = {
    BOTTOM_LEFT = { front = { ch=633 } , back = { ch=-1 } },
    BOTTOM_RIGHT = { front = { ch=641 }, back = { ch=-1 } },
    TOP_RIGHT = { front = { ch=649 }, back = { ch=-1 } },
  },

  MCP = {
    [1] = { 
      QDC = {
        TOP_RIGHT = { ch=865 }, 
        TOP_LEFT = { ch=866 }, 
        BOTTOM_LEFT = { ch=867 }, 
        BOTTOM_RIGHT = { ch=868 } 
      }, 

      MPD4 = {
        TOP_RIGHT = { ch=617, threshold=101 }, 
        TOP_LEFT = { ch=618, threshold=100 }, 
        BOTTOM_LEFT = { ch=619, threshold=119 }, 
        BOTTOM_RIGHT = { ch=620, threshold=76 } 
      },
    },

    [2] = { 
      QDC = {
        TOP_RIGHT = { ch=869 }, 
        TOP_LEFT = { ch=870 }, 
        BOTTOM_LEFT = { ch=871 }, 
        BOTTOM_RIGHT = { ch=872 } 
      },

      MPD4 = {
        TOP_RIGHT = { ch=621, threshold=125 }, 
        TOP_LEFT = { ch=622, threshold=106 }, 
        BOTTOM_LEFT = { ch=623, threshold=95 }, 
        BOTTOM_RIGHT = { ch=624, threshold=102 } 
      },
    }
  },

  TDC = {
    E1 = { ch=805 }, XF = { ch=806 }, RF = { ch=807 }, MCP1 = { ch=809 }, MCP2 = { ch=810 },
  }
}

local function MakeChannelToDetector()
  local chan_to_det, det_to_chan = {}, {}

  for k, dets in pairs(mapping) do
    for det, v in pairs(dets) do
      if type(v) == "table" and v.front then
        for i= 1, detectors_properties[k].front.connectors or detectors_properties[k].front.strips do
          local fkey = k.." "..tostring(det).." "..(v.back == nil and "" or "f")..tostring(i)
          local chnum = v.front.ch+i-1
          chan_to_det[chnum] = {stripid = fkey, detid = det, dettype = k, stripnum = i}
          det_to_chan[fkey] = {channel = chnum, detid = det, dettype = k, stripnum = i}
        end
      end

      if type(v) == "table" and v.back then
        for i= 1, detectors_properties[k].back.connectors or detectors_properties[k].back.strips do
          local bkey = k.." "..tostring(det).." b"..tostring(i)
          local chnum = v.back.ch+i-1
          chan_to_det[chnum] = {stripid = fkey, detid = det, dettype = k, stripnum = i}
          det_to_chan[bkey] = {channel = chnum, detid = det, dettype = k, stripnum = i}
        end
      end

      if k == "MCP" then
        for mod, chs in pairs(v) do
          for attr, chinfo in pairs(chs) do
            local fkey = k.." "..tostring(det).." "..tostring(mod).. " "..tostring(attr)
            chan_to_det[chinfo.ch] = {stripid = fkey, detid = det, dettype = k, detmod = mod, stripnum = attr}
            det_to_chan[fkey] = {channel = chinfo.ch, detid = det, dettype = k, detmod = mod, stripnum = i}
          end
        end
      end
    end

    if k == "TDC" then
      for det, chinfo in pairs(dets) do
        local fkey = k.." "..tostring(det)
        chan_to_det[chinfo.ch] = {stripid = fkey, detid = det, dettype = k}
        det_to_chan[fkey] = {channel = chinfo.ch, detid = det, dettype = k}
      end
    end
  end

  return chan_to_det, det_to_chan
end

chan_to_det, det_to_chan = MakeChannelToDetector()

local function ToAdcChannel(key)
  return det_to_chan[key].channel
end

local function ToAdcChannels(det, side)
  local type = det:sub(1, det:find(" ")-1)

  local chs = {}

  if side == nil or side == "f" or side == "front" then
    local prop = detectors_properties[type].front
    local nchans = prop.connectors and prop.connectors or prop.strips

    for i=1, nchans do
      table.insert(chs, det_to_chan[det..(side and " f" or " ")..tostring(i)].channel)
    end
  elseif side == "b" or side == "back" then
    local prop = detectors_properties[type].back
    local nchans = prop.connectors and prop.connectors or prop.strips

    for i=1, nchans do
      table.insert(chs, det_to_chan[det.." b"..tostring(i)].channel)
    end
  end

  return chs
end

local function ToDetKey(channel)
  return chan_to_det[channel].stripid
end

local function ToDetInfo(channel)
  return chan_to_det[channel]
end

return {getchannel=ToAdcChannel, getchannels=ToAdcChannels, getdetkey=ToDetKey, getdetinfo=ToDetInfo, det_prop=detectors_properties}