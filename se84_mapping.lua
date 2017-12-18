local detectors_properties = {
  SIDAR = { front = {strips = 16}},

  BB10 = { front = {strips = 8}},

  SuperX3 = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7} }, back = {strips = 4} },

  X3 = { front = {strips = 1}},

  Elastics = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7}}, back = {strips = 1} }
}

local mapping = {
  SIDAR = {
    dE1 = { front = { ch=1  } },
    dE2 = { front = { ch=17 } },
    dE3 = { front = { ch=33 } },
    dE4 = { front = { ch=49 } },
    dE5 = { front = { ch=65 } },
    dE6 = { front = { ch=81 } },

    E1 = { front = { ch=101 } },
    E2 = { front = { ch=117 } },
    E3 = { front = { ch=133 } },
    E4 = { front = { ch=149 } },
    E5 = { front = { ch=165 } },
    E6 = { front = { ch=181 } },
  },

  BB10 = {
    U1  =  { front = { ch=201 } },
    U2  =  { front = { ch=209 } },
    U3  =  { front = { ch=217 } },
    U4  =  { front = { ch=225 } },
    U5  =  { front = { ch=233 } },
    U6  =  { front = { ch=241 } },
    U7  =  { front = { ch=249 } },
    U8  =  { front = { ch=257 } },
    U9  =  { front = { ch=265 } },
    U10 = { front = { ch=273 } },
    U11 = { front = { ch=281 } },
    U12 = { front = { ch=289 } },
  },

  SuperX3 = {
    U1 =  { front = { ch=301 } , back = { ch=501 } },
    U2 =  { front = { ch=309 } , back = { ch=505 } },
    U3 =  { front = { ch=317 } , back = { ch=509 } },
    U4 =  { front = { ch=325 } , back = { ch=513 } },
    U5 =  { front = { ch=333 } , back = { ch=533 } },
    U6 =  { front = { ch=341 } , back = { ch=537 } },
    U7 =  { front = { ch=349 } , back = { ch=517 } },
    U8 =  { front = { ch=357 } , back = { ch=521 } },
    U9 =  { front = { ch=365 } , back = { ch=525 } },
    U10 = { front = { ch=373 } , back = { ch=529 } },
    U11 = { front = { ch=381 } , back = { ch=541 } },
    U12 = { front = { ch=389 } , back = { ch=545 } },

    D1 =  { front = { ch=401 } , back = { ch=549 } },
    D2 =  { front = { ch=409 } , back = { ch=553 } },
    D3 =  { front = { ch=417 } , back = { ch=557 } },
    D4 =  { front = { ch=425 } , back = { ch=561 } },
    D5 =  { front = { ch=433 } , back = { ch=581 } },
    D6 =  { front = { ch=441 } , back = { ch=585 } },
    D7 =  { front = { ch=449 } , back = { ch=565 } },
    D8 =  { front = { ch=457 } , back = { ch=569 } },
    D9 =  { front = { ch=465 } , back = { ch=573 } },
    D10 = { front = { ch=473 } , back = { ch=577 } },
    D11 = { front = { ch=481 } , back = { ch=589 } },
    D12 = { front = { ch=489 } , back = { ch=593 } },
  },

  X3 = {
    dE1  =  { front = { ch=604 } },
    dE2  =  { front = { ch=603 } },
    dE3  =  { front = { ch=602 } },
    dE4  =  { front = { ch=601 } },
    dE5  =  { front = { ch=606 } },
    dE6  =  { front = { ch=605 } },
    dE7  =  { front = { ch=612 } },
    dE8  =  { front = { ch=611 } },
    dE9  =  { front = { ch=610 } },
    dE10 =  { front = { ch=609 } },
    dE11 =  { front = { ch=614 } },
    dE12 =  { front = { ch=613 } },
  },

  Elastics = {
    BOTTOMLEFT = { front = { ch=633 } , back = { ch=-1 } },
    BOTTOMRIGHT = { front = { ch=641 }, back = { ch=-1 } },
    TOPRIGHT = { front = { ch=649 }, back = { ch=-1 } },
  },

  MCP = {
    TRACK1 = { 
      QDC = {
        TOPRIGHT = { ch=865 }, 
        TOPLEFT = { ch=866 }, 
        BOTTOMLEFT = { ch=867 }, 
        BOTTOMRIGHT = { ch=868 } 
      }, 

      MPD4 = {
        TOPRIGHT = { ch=617, threshold=101 }, 
        TOPLEFT = { ch=618, threshold=100 }, 
        BOTTOMLEFT = { ch=619, threshold=119 }, 
        BOTTOMRIGHT = { ch=620, threshold=76 } 
      },
    },

    TRACK2 = { 
      QDC = {
        TOPRIGHT = { ch=869 }, 
        TOPLEFT = { ch=870 }, 
        BOTTOMLEFT = { ch=871 }, 
        BOTTOMRIGHT = { ch=872 } 
      },

      MPD4 = {
        TOPRIGHT = { ch=621, threshold=125 }, 
        TOPLEFT = { ch=622, threshold=106 }, 
        BOTTOMLEFT = { ch=623, threshold=95 }, 
        BOTTOMRIGHT = { ch=624, threshold=102 } 
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
      local detnum = det:match("%d+")
      local detpos = det:match("%a+")

      if type(v) == "table" and v.front then
        for i= 1, detectors_properties[k].front.connectors or detectors_properties[k].front.strips do
          local fkey = k.." "..tostring(det).." "..(v.back == nil and "" or "f")..tostring(i)
          local chnum = v.front.ch+i-1
          chan_to_det[chnum] = {stripid = fkey, detnum = detnum, detpos = detpos, detside = "front", detid = det, dettype = k, stripnum = i}
          det_to_chan[fkey] = {channel = chnum, detnum = detnum, detpos = detpos, detside = "front", detid = det, dettype = k, stripnum = i}
        end
      end

      if type(v) == "table" and v.back then
        for i= 1, detectors_properties[k].back.connectors or detectors_properties[k].back.strips do
          local bkey = k.." "..tostring(det).." b"..tostring(i)
          local chnum = v.back.ch+i-1
          chan_to_det[chnum] = {stripid = fkey, detnum = detnum, detpos = detpos, detside = "back", detid = det, dettype = k, stripnum = i}
          det_to_chan[bkey] = {channel = chnum, detnum = detnum, detpos = detpos, detside = "back", detid = det, dettype = k, stripnum = i}
        end
      end

      if k == "MCP" then
        for mod, chs in pairs(v) do
          for attr, chinfo in pairs(chs) do
            local fkey = k.." "..tostring(det).." "..tostring(mod).. " "..tostring(attr)
            chan_to_det[chinfo.ch] = {stripid = fkey, detnum = detnum, detpos = detpos, detid = det, dettype = k, detmod = mod, stripnum = attr}
            det_to_chan[fkey] = {channel = chinfo.ch, detnum = detnum, detpos = detpos, detid = det, dettype = k, detmod = mod, stripnum = i}
          end
        end
      end
    end

    if k == "TDC" then
      for det, chinfo in pairs(dets) do
        local fkey = k.." "..tostring(det)
        chan_to_det[chinfo.ch] = {stripid = fkey, detnum = detnum, detpos = detpos, detid = det, dettype = k}
        det_to_chan[fkey] = {channel = chinfo.ch, detnum = detnum, detpos = detpos, detid = det, dettype = k}
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

local function ToDetInfo(detid)
  if chan_to_det[channel] then return chan_to_det[channel]
  elseif det_to_chan[detid] then return det_to_chan[detid]
  else return nil
  end
end

return {getchannel=ToAdcChannel, getchannels=ToAdcChannels, getdetkey=ToDetKey, getdetinfo=ToDetInfo, det_prop=detectors_properties}