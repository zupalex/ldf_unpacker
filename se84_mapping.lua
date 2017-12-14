local detectors_properties = {
  SIDAR = { front = {strips = 16}},

  BB10 = { front = {strips = 8}},

  SuperX3 = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7} }, back = {strips = 4} },

  X3 = { front = {strips = 1}},

  Elastics = { front = {strips = 4, connectors = 8, order = {1, 2, 3, 4, 6, 5, 8, 7}}, back = {strips = 1} }
}

local mapping = {
  SIDAR = {
    dE1 = { front = 1  },
    dE2 = { front = 17 },
    dE3 = { front = 33 },
    dE4 = { front = 49 },
    dE5 = { front = 65 },
    dE6 = { front = 81 },

    E1 = { front = 101 },
    E2 = { front = 117 },
    E3 = { front = 133 },
    E4 = { front = 149 },
    E5 = { front = 165 },
    E6 = { front = 181 },
  },

  BB10 = {
    [1] =  { front = 201 },
    [2] =  { front = 209 },
    [3] =  { front = 217 },
    [4] =  { front = 225 },
    [5] =  { front = 233 },
    [6] =  { front = 241 },
    [7] =  { front = 249 },
    [8] =  { front = 257 },
    [9] =  { front = 265 },
    [10] = { front = 273 },
    [11] = { front = 281 },
    [12] = { front = 289 },
  },

  SuperX3 = {
    U1 =  { front = 301 , back = 501 },
    U2 =  { front = 309 , back = 505 },
    U3 =  { front = 317 , back = 509 },
    U4 =  { front = 325 , back = 513 },
    U5 =  { front = 333 , back = 533 },
    U6 =  { front = 341 , back = 537 },
    U7 =  { front = 349 , back = 517 },
    U8 =  { front = 357 , back = 521 },
    U9 =  { front = 365 , back = 525 },
    U10 = { front = 373 , back = 529 },
    U11 = { front = 381 , back = 541 },
    U12 = { front = 389 , back = 545 },

    D1 =  { front = 401 , back = 549 },
    D2 =  { front = 409 , back = 553 },
    D3 =  { front = 417 , back = 557 },
    D4 =  { front = 425 , back = 561 },
    D5 =  { front = 433 , back = 581 },
    D6 =  { front = 441 , back = 585 },
    D7 =  { front = 449 , back = 565 },
    D8 =  { front = 457 , back = 569 },
    D9 =  { front = 465 , back = 573 },
    D10 = { front = 473 , back = 577 },
    D11 = { front = 481 , back = 589 },
    D12 = { front = 489 , back = 593 },
  },

  X3 = {
    [1]  =  { front = 604 },
    [2]  =  { front = 603 },
    [3]  =  { front = 602 },
    [4]  =  { front = 601 },
    [5]  =  { front = 606 },
    [6]  =  { front = 605 },
    [7]  =  { front = 612 },
    [8]  =  { front = 611 },
    [9]  =  { front = 610 },
    [10] =  { front = 609 },
    [11] =  { front = 614 },
    [12] =  { front = 613 },
  },

  Elastics = {
    BOTTOM_LEFT = { front = 633, back = -1 },
    BOTTOM_RIGHT = { front = 641, back = -1 },
    TOP_RIGHT = { front = 649, back = -1 },
  },

  MCP = {
    [1] = { 
      QDC = {TOP_RIGHT = 865, TOP_LEFT = 866, BOTTOM_LEFT = 867, BOTTOM_RIGHT = 868}, 
      MPD4 = {TOP_RIGHT = 617, TOP_LEFT = 618, BOTTOM_LEFT = 619, BOTTOM_RIGHT = 620}
    },

    [2] = { 
      QDC = {TOP_RIGHT = 869, TOP_LEFT = 870, BOTTOM_LEFT = 871, BOTTOM_RIGHT = 872},
      MPD4 = {TOP_RIGHT = 621, TOP_LEFT = 622, BOTTOM_LEFT = 623, BOTTOM_RIGHT = 624}
    }
  },

  TDC = {
    E1 = 805, XF = 806, RF = 807, MCP1 = 809, MCP2 = 810,
  }
}

local function MakeChannelToDetector()
  local chan_to_det, det_to_chan = {}, {}

  for k, dets in pairs(mapping) do
    for det, v in pairs(dets) do
      if type(v) == "table" and v.front then
        for i= 1, detectors_properties[k].front.connectors or detectors_properties[k].front.strips do
          local fkey = k.." "..tostring(det).." "..(v.back == nil and "" or "f")..tostring(i)
          local chnum = v.front+i-1
          chan_to_det[chnum] = {stripid = fkey, detid = det, dettype = k, stripnum = i}
          det_to_chan[fkey] = {channel = chnum, detid = det, dettype = k, stripnum = i}
        end
      end

      if type(v) == "table" and v.back then
        for i= 1, detectors_properties[k].back.connectors or detectors_properties[k].back.strips do
          local bkey = k.." "..tostring(det).." b"..tostring(i)
          local chnum = v.back+i-1
          chan_to_det[chnum] = {stripid = fkey, detid = det, dettype = k, stripnum = i}
          det_to_chan[bkey] = {channel = chnum, detid = det, dettype = k, stripnum = i}
        end
      end

      if k == "MCP" then
        for mod, chs in pairs(v) do
          for attr, chnum in pairs(chs) do
            local fkey = k.." "..tostring(det).." "..tostring(mod).. " "..tostring(attr)
            chan_to_det[chnum] = {stripid = fkey, detid = det, dettype = k, detmod = mod, stripnum = attr}
            det_to_chan[fkey] = {channel = chnum, detid = det, dettype = k, detmod = mod, stripnum = i}
          end
        end
      end
    end

    if k == "TDC" then
      for det, ch in pairs(dets) do
        local fkey = k.." "..tostring(det)
        chan_to_det[ch] = {stripid = fkey, detid = det, dettype = k}
        det_to_chan[fkey] = {channel = ch, detid = det, dettype = k}
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