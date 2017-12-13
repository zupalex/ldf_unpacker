local calfile = "/mnt/hgfs/Dropbox/ORNL/software/luaXroot/user/ldf_unpacker/cal_params_alpha_cal_E_01.txt"
local resisitive_calfile = "/mnt/hgfs/Dropbox/ORNL/software/luaXroot/user/ldf_unpacker/test_resistive.txt"

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local mapping = require("ldf_unpacker/se84_mapping")

local cal_input, rescal_input
local det_cal = {}
local ch_cal = {}

local function ReadSX3BacksideParams(cur_det, det_cal, ch_cal)
  local line = cal_input:read("l")

  while line do
    local pIter = line:gmatch("-?%d+%.?%d*")

    local strip, front1, front2, slope, offset = pIter(), pIter(), pIter(), pIter(), pIter()

    if strip and front1 and front2 and slope and offset then
      if det_cal[cur_det.." b"..tostring(strip)] == nil then
        local chfs = mapping.getchannels(cur_det, "front")

        det_cal[cur_det.." b"..tostring(strip)] = {}

        local det_cal_ref = det_cal[cur_det.." b"..tostring(strip)]

        local getparsfn = function(ev)
          if ev[chfs[1]] and ev[chfs[2]] then return det_cal_ref[1]
          elseif ev[chfs[3]] and ev[chfs[4]] then return det_cal_ref[2]
          elseif ev[chfs[5]] and ev[chfs[6]] then return det_cal_ref[3]
          elseif ev[chfs[7]] and ev[chfs[8]] then return det_cal_ref[4] end
        end

        det_cal_ref.getparsfn = getparsfn

        function det_cal_ref:calibrate(en, ev)
          local calpars = self.getparsfn(ev)
          return calpars and (calpars.slope * en + calpars.offset) or 0
        end
      end

      local cal_tbl = {slope=slope, offset=offset}
      local fkey = math.floor(front1/2)+1

      det_cal[cur_det.." b"..tostring(strip)][fkey] = cal_tbl
      ch_cal[mapping.getchannel(cur_det.." b"..tostring(strip))] = det_cal[cur_det.." b"..tostring(strip)]

      line = cal_input:read("l")
    else
      return line
    end
  end
end

local function ReadSX3FrontsideParams(cur_det, det_cal, ch_cal)
  local line = rescal_input:read("l")

  while line do
    local strip_pos = line:find("Res. Strip #")
    if strip_pos then
      strip_pos = strip_pos+11

      local pIter = line:gmatch("-?%d+%.?%d*")

      local strip, offX, offY, gain_match, slope, left_edge_pos, right_edge_pos = pIter(), pIter(), pIter(), pIter(), pIter(), pIter(), pIter()

      if strip and offX and offY and gain_match and slope and left_edge_pos and right_edge_pos then
        local order = mapping.det_prop.SuperX3.front.order
        local order_index = 2*(strip-1)+1

        local width = right_edge_pos-left_edge_pos
        local pos_offset = (right_edge_pos+left_edge_pos)/2

        local nearKey, farKey = cur_det.." f"..tostring(order[order_index]), cur_det.." f"..tostring(order[order_index+1])

        det_cal[nearKey] = { offset=offX, gain_match=gain_match, width=width, pos_offset=pos_offset, slope=slope, type="near"}
        det_cal[farKey] = { offset=offY, gain_match=1.0, width=width, pos_offset=pos_offset, slope=slope, type="far"}

        det_cal[nearKey].friend = det_cal[farKey]
        det_cal[farKey].friend = det_cal[nearKey]

        local function calibrate(self, en, ev)
          local enCal = (en*self.gain_match - self.offset)*(self.slope or 1)
          self.enCal = enCal
          return enCal
        end

        local function gethitpos(self)
          local enSum = self.enCal + self.friend.enCal
          local enDiff = (self.type=="near") and (self.enCal - self.friend.enCal) or (self.friend.enCal - self.enCal)
          local pos = ((enDiff / enSum) - self.pos_offset) / self.width

          self.pos = pos
          self.friend.pos = pos

          return pos
        end

        det_cal[nearKey].calibrate = calibrate
        det_cal[farKey].calibrate = calibrate

        det_cal[nearKey].gethitpos = gethitpos
        det_cal[farKey].gethitpos = gethitpos

        ch_cal[mapping.getchannel(nearKey)] = det_cal[nearKey]
        ch_cal[mapping.getchannel(farKey)] = det_cal[farKey]

        line = rescal_input:read("l")
      else
        return line
      end
    else
      line = rescal_input:read("l")
    end
  end
end

local function ReadSIDARParams(cur_det, det_cal, ch_cal)
  local line = cal_input:read("l")

  while line do
    local pIter = line:gmatch("-?%d+%.?%d*")

    local strip, slope, offset = pIter(), pIter(), pIter()

    if strip and slope and offset then
      det_cal[cur_det.." "..tostring(strip)] = {slope=slope, offset=offset}

      det_cal[cur_det.." "..tostring(strip)].calibrate = function(self, en, ev)
        return self.slope*en + self.offset
      end

      ch_cal[mapping.getchannel(cur_det.." "..tostring(strip))] = det_cal[cur_det.." "..tostring(strip)]

      line = cal_input:read("l")
    else
      return line
    end
  end
end

local function ReadBB10Params(cur_det, det_cal, ch_cal)
  local line = cal_input:read("l")

  while line do
    local pIter = line:gmatch("-?%d+%.?%d*")

    local strip, slope, offset = pIter(), pIter(), pIter()

    if strip and slope and offset then
      det_cal[cur_det.." "..tostring(strip)] = {slope=slope, offset=offset}

      det_cal[cur_det.." "..tostring(strip)].calibrate = function(self, en, ev)
        return self.slope*en + self.offset
      end

      ch_cal[mapping.getchannel(cur_det.." "..tostring(strip))] = det_cal[cur_det.." "..tostring(strip)]

      line = cal_input:read("l")
    else
      return line
    end
  end
end

local function ReadX3Params(cur_det, det_cal, ch_cal)
  local line = cal_input:read("l")

  while line do
    print(line)

    local pIter = line:gmatch("-?%d+%.?%d*")

    local strip, slope, offset = pIter(), pIter(), pIter()

    if strip and slope and offset then
      det_cal[cur_det.." "..tostring(strip)] = {slope=slope, offset=offset}

      det_cal[cur_det.." "..tostring(strip)].calibrate = function(self, en, ev)
        return self.slope*en + self.offset
      end

      ch_cal[mapping.getchannel(cur_det.." "..tostring(strip))] = det_cal[cur_det.." "..tostring(strip)]

      line = cal_input:read("l")
    else
      return line
    end
  end
end

local function ReadCal()
  local line, cur_det

  cal_input = io.open(calfile, "r")

  if cal_input then
    line = cal_input:read("l")

    while line do
      if cur_det == nil then
        local pIter = line:gmatch("-?%a+%d*")

        local dtype, dId = pIter(), pIter()

        if mapping.det_prop[dtype] then
          cur_det = dtype.." "..dId
        else
          line = cal_input:read("l")
        end
      else
        if line:find("SuperX3") and line:find("back side") then
          line = ReadSX3BacksideParams(cur_det, det_cal, ch_cal)
        elseif line:find("SIDAR") then
          line = ReadSIDARParams(cur_det, det_cal, ch_cal)
        elseif line:find("BB10") then
          line = ReadBB10Params(cur_det, det_cal, ch_cal)
        elseif line:find("X3") and line:find("Super") == nil then
          line = ReadX3Params(cur_det, det_cal, ch_cal)
        end

        cur_det = nil
      end
    end
  end

  cur_det = nil
  rescal_input = io.open(resisitive_calfile, "r")

  if rescal_input then
    line = rescal_input:read("l")

    local cur_strip

    while line do
      if cur_det == nil then
        local pIter = line:gmatch("%a+%d*")

        local dtype, dId = pIter(), pIter()

        if mapping.det_prop[dtype] then
          cur_det = dtype.." "..dId
        else
          line = rescal_input:read("l")
        end      
      else
        line = ReadSX3FrontsideParams(cur_det, det_cal, ch_cal)
      end
    end
  end

  return ch_cal, det_cal
end

local function GetPars(id,ev)
  local det_cal_ref = det_cal[id]

  if det_cal_ref then
    if det_cal_ref.getparsfn then
      return det_cal_ref.getparsfn(ev)
    else
      return det_cal_ref
    end
  else
    return {slope=0, off=0}
  end
end

local function Calibrate(id, en, ev)
  return det_cal[id]:calibrate(en, ev)
end

return {readcal = ReadCal, getpars = GetPars, calibrate = Calibrate}