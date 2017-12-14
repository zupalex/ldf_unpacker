require("binaryreader")

mapping = require("ldf_unpacker/se84_mapping")
calib = require("ldf_unpacker/se84_calibration")

require("ldf_unpacker/ornldaq_signals")
require("ldf_unpacker/ornldaq_monitors")

local ldfEventCounter = 0

local ldf_word_size = 4 -- in bytes
local ldf_evt_size = 8194*ldf_word_size -- in bytes

printDebug = false

local bindata = {
  file = nil,

  cur_idx = nil,

  currPos = nil,
  lastReadRecord = nil,

  nrec = nil,
  nhed = nil,

  record = nil,
  type = nil,
  nWords = nil,
  data = nil
}

local function OpenInputFile(ifile)
  if bindata.file ~= nil then
    bindata.file:close()
    bindata.file = nil
  end

  bindata.file = assert(io.open(ifile, "rb"))
end

function GetLDFRecord()  
  if bindata.file == nil then
    print("ERRROR: no file has been loaded")
    return
  end

  bindata.record = bindata.file:read(8194*4)

  bindata.cur_idx = 9
end

function GetRecordType(record)
  bindata.cur_idx = 5
  return record:sub(1,4)
end

function GetNWords(record)
  bindata.cur_idx = 9
  return string.unpack("<I4", record:sub(5, 8))
end

function GetNextWord(record, offset, invert)
  local buffer = record:sub(offset, offset+3)
  offset = offset + 4

  local nextWord

  if invert then
    nextWord = DecodeBytes(buffer, ">I4")
  else
    nextWord = DecodeBytes(buffer, "<I4")
  end

  return offset, nextWord
end

local UnpackRecord = {
  ["HEAD"] = function() 
    print("header record: " .. tostring(bindata.record:sub(9,264))) 
    return bindata.type
  end,

  ["DIR "] = function()
    bindata.cur_idx = GetNextWord(bindata.record, bindata.cur_idx)
    bindata.cur_idx, bindata.nrec = GetNextWord(bindata.record, bindata.cur_idx)
    bindata.cur_idx = GetNextWord(bindata.record, bindata.cur_idx)
    bindata.cur_idx, bindata.nhed = GetNextWord(bindata.record, bindata.cur_idx)

    local hid = {}
    local recn = {}

    for i=1,bindata.nhed do
      local buffer
      bindata.cur_idx, buffer = GetNextWord(bindata.record, bindata.cur_idx)
      table.insert(hid, buffer)
      bindata.cur_idx, buffer = GetNextWord(bindata.record, bindata.cur_idx)
      table.insert(recn, buffer)
    end

    return bindata.type, nil, hid, recn
  end,

  ["DATA"] = function(length)
    local data = {}
    local new_ev = {}
    local mult = 0
    -- local fired = {}

    if length == nil then length = 8192 end

    for i=1,length do
      local buffer
      buffer, bindata.cur_idx = DecodeBytes(bindata.record, "I4", bindata.cur_idx)

      if buffer == 0xffffffff then
        if raw_dump then print("--------------- End Of Event ---------------") end
        if mult > 0 then
          table.insert(data, new_ev)
          new_ev = {}
          mult = 0
          -- fired = {}
        end
      else
        local value = (buffer >> 16) & 0xffff
        local channel = buffer & 0x7fff

        if raw_dump then print("Channel " .. tostring(channel) .. " => " .. tostring(value)) end
--        print("Channel " .. tostring(channel) .. " => " .. tostring(value))

        new_ev[channel]= value
        mult = mult+1

        -- if fired[channel] == nil then
        -- new_ev[channel]= value
        -- fired[channel] = true
        -- end
      end
    end

    return bindata.type, data, mult
  end,

  ["EOF "] = function() return nil end,
}

local function ReadNextRecordDisk(raw_dump, skip_readrecord)
  if not skip_readrecord then GetLDFRecord() end

  if bindata.record == nil then
    return nil
  end

  bindata.type = GetRecordType(bindata.record)
  bindata.nWords = GetNWords(bindata.record)

  if raw_dump then print("Type:", bindata.type, "/ number of words:", bindata.nWords) end

  local unpackfn = UnpackRecord[bindata.type] or function() return bindata.type end

  return unpackfn()
end

local function ReadNextRecordTCP(bufsize, raw_dump)
  if bindata.record == nil then
    return nil
  end

  return UnpackRecord["DATA"](bufsize/4)
end

ReadNextRecord = ReadNextRecordDisk

function SetReadMode(mode)
  if mode:lower() == "file" or mode:lower() == "disk" then
    ReadNextRecord = ReadNextRecordDisk
  elseif mode:lower() == "tcp" or mode:lower() == "network" or mode:lower() == "net" then
    ReadNextRecord = ReadNextRecordTCP
  else
    print("ERROR: Invalid read mode specified =>", mode)
  end
end

function DumpNextRecord(raw_dump)
  local htype, data, hid, recn = ReadNextRecord(raw_dump)

  print("Record Type: " .. tostring(bindata.type))
  print("Number of 32bits words in the record: " .. tostring(bindata.nWords))

  if header_types[htype] == "DIR " then
    print("number of records written on file: " .. tostring(bindata.nrec))
    print("number of header records written on file: " .. tostring(bindata.nhed))

    for i=1,bindata.nhed do
      print("header ID number: " .. tostring(hid[i]))
      print("record number where header is written: " .. tostring(recn[i]))
    end
  elseif header_types[htype] == "DATA" and not raw_dump then
    print("************ DATA packet ************")

    for i, ev in ipairs(data) do
      print("    -------- Event "..tostring(i) .." --------")
      for _, v in ipairs(ev) do
        print("Channel " .. tostring(v.channel) .. " <-> " .. tostring(v.value))
      end
    end
  end
end

function StartMonitoring(input, raw_dump, replay)
  MakeSyncSafe()

  OpenInputFile(type(input) == "table" and input[1] or input)

  AddSignal("display", function(hname, opts)
      if haliases[hname] then haliases[hname].hist:Draw(opts)
      elseif orruba_monitors[hname] then orruba_monitors[hname].hist:Draw(opts) end
    end)

  SetupStandardMonitors()

  if bindata.file == nil then
    print("no input file...")
    return
  end

--  for _, h in pairs(orruba_monitors) do
--    if h.type == "1D" then h.hist:Draw()
--    else h.hist:Draw("colz") end
--  end

  orruba_monitors.h_monitor.hist:Draw("colz")

  local totRecords = 0

  if bindata.lastReadRecord == nil then bindata.lastReadRecord = 0 end

  while CheckSignals() do
    bindata.currPos = bindata.file:seek("cur")
    local flen = bindata.file:seek("end")
    bindata.file:seek("set", bindata.currPos)

    local nNewRecord = (flen-bindata.currPos) / ldf_evt_size
    totRecords = flen / ldf_evt_size

    local nRecordsToRead = math.floor(totRecords - bindata.lastReadRecord)

--    print("File length at", os.time(), "is", flen, "... Number of new words:", nNewRecord,"/ Total =", totRecords, "/ Records to read =", nRecordsToRead)

    if nRecordsToRead > 0 then
      for i=1, nRecordsToRead do
        local htype, data = ReadNextRecord(raw_dump)
--        if htype == "DIR " then print("Read record #"..tostring(bindata.lastReadRecord+i), "type =")
--        elseif htype == "DATA" then print("Read record #"..tostring(bindata.lastReadRecord+i), "type =", header_types[htype], "events =", #data) end

        if htype == "DATA" then
          for i, ev in ipairs(data) do
            for _, h in pairs(orruba_monitors) do
              h.fillfn(h.hist, ev)
            end
          end
        end

        if i%100 == 0 then
          CheckSignals()
          theApp:Update()
        end
      end

      theApp:Update()

    elseif replay then
      if type(input) == "string" or #input == 1 then
        break
      else
        print("Finished processing", input[1], "... switching to", input[2])
        table.remove(input, 1)
        OpenInputFile(input[1])
        bindata.lastReadRecord = 0
      end
    end

    theApp:ProcessEvents()

    bindata.lastReadRecord = bindata.lastReadRecord + nRecordsToRead

    sleep(2)
  end

  for k, v in pairs(orruba_monitors) do
    theApp:Update()
  end



  theApp:Update()

  MakeSyncSafe(false)
end

------------------------------- Simple function to read a file as it is written and send it over the network ---------------------------

local ldf_packetSize = 8194*4

local send_fpos = 0

function SendLDFRecord(sender)
  local flen = bindata.file:seek("end")

  if flen - send_fpos >= ldf_packetSize then
    bindata.file:seek("set", send_fpos)
    data = bindata.file:read(ldf_packetSize)
    send_fpos = bindata.file:seek("cur")

    local bsent = sender:WaitAndSend(data, ldf_packetSize)

    if bsent ~= ldf_packetSize then
      print("Amount of bytes sent (", bsent, ")different than expected (", ldf_packetSize, ")")
    end

    local bread, resp = sender:WaitAndReadResponse(sender.clientsfd[1])

    if resp ~= "done" then
      print("Response of client unexpected:", resp)
    end

    return true
  end
end

function StartBroadcasting(filename, address)
  local socket = require("lua_sockets")
  bindata.file = assert(io.open(filename, "rb"))

  local currPos = bindata.file:seek("cur")

  local sender = socket.CreateHost("net", address)

  local psent = 0

  print("Connection established...")

  while CheckSignals() do
    if SendLDFRecord(sender) then
      psent=psent+1
      io.write("Broadcasted "..psent.." packets\r")
      io.flush()
    else
      sleep(1)
    end
  end
end

------------------------------- Function to receive data over the network ---------------------------

function BufferORNLSenderData(mastertaskname, address)
  print("Setting up the buffering for task", mastertaskname)

  local receiver = socket.CreateClient("net", address)

  local bufid = 0
--  local max_send = 20

  if not receiver then
    SendSignal(mastertaskname, "socketfailed")
    return
  end

  print("Receiver connected to", address)

  local ornl_buffer, ornl_headers = {}, {}

  AddSignal("sendrequest", function()
      SendSignal(mastertaskname, "receivebuffer", ornl_buffer, ornl_headers, bufid)
      ornl_buffer = {}
      ornl_headers = {}
      bufid = 0
    end)

  print("Signals established")

  while CheckSignals() do
    local bytesread, prev_read, buff_table = 0, 0, {}
    buff_table[#buff_table+1], bytesread = receiver:WaitAndReceive(16, true)

    while bytesread < 16 do
      prev_read = bytesread
      buff_table[#buff_table+1], bytesread = receiver:WaitAndReceive(16-bytesread, true)
      bytesread = prev_read+bytesread
    end

    local evt_num, nevt, bufsize, buf_num, offset

    local buffheader = table.concat(buff_table)

    evtnum, offset = DecodeBytes(buffheader, "I4", offset)
    nevt, offset = DecodeBytes(buffheader, "i4", offset)
    bufsize, offset = DecodeBytes(buffheader, "i4", offset)
    buf_num, offset = DecodeBytes(buffheader, "i4", offset)

    buff_table = {}
    bytesread = 0
    prev_read = 0

    buff_table[#buff_table+1], bytesread = receiver:WaitAndReceive(bufsize, true)

    while bytesread < bufsize do
      prev_read = bytesread
      buff_table[#buff_table+1], bytesread = receiver:WaitAndReceive(bufsize-bytesread, true)
      bytesread = prev_read+bytesread
    end

    ornl_buffer[bufid+1] = table.concat(buff_table)
    ornl_headers[bufid+1] = {bufsize=bufsize, evtnum=evtnum, nevt=nevt, buf_num=buf_num}

    bufid = bufid+1

    SendSignalUnique(mastertaskname, "getbuffersize", bufid)
  end
end

function Showh(hname, opts)
  SendSignal("monitor", "display", hname, opts)
end

function ListHistograms(alias, ...)
  local matches

  if type(alias) == "string" then
    matches = table.pack(alias, ...)
    alias = true
  else
    matches = table.pack(...)
  end

  SendSignal("ornlmonitor", "ls", alias, matches, false)
end

local function checknamematch(name, matches)
  if #matches == 0 then return true end

  for _, m in ipairs(matches) do
    if name:find(m) == nil then
      return false
    end
  end

  return true
end

function AttachToORNLSender(address, buffername)
  SetReadMode("tcp")

  local stopexec = false
  local receiver_bufnum, ldfbuffers, buf_headers = 0, {}, {}

  AddSignal("receivebuffer", function(buffers, headers, nbufs)
      ldfbuffers = buffers
      buf_headers = headers
      if nbufs ~= #headers then print("Warning: received inconsistent information => nbufs =", nbufs, " while #headers =", #headers) end
    end)

  AddSignal("socketfailed", function()
      stopexec = true
    end)

  AddSignal("getbuffersize", function(bn)
      receiver_bufnum = bn
    end)

  AddSignal("display", function(hname, opts)
      if haliases[hname] then haliases[hname].hist:Draw(opts)
      elseif orruba_monitors[hname] then orruba_monitors[hname].hist:Draw(opts) end
    end)

  AddSignal("display_multi", function(divx, divy, hists)
      local can = TCanvas()
      can:Divide(divx, divy)

      for i, v in ipairs(hists) do
        local row_ = math.floor((i-1)/divy)+1
        local col_ = i - divy*(row_-1)
        if haliases[v.hname] then can:Draw(haliases[v.hname].hist, v.opts, row_, col_)
        elseif orruba_monitors[v.hname] then can:Draw(orruba_monitors[v.hname].hist, v.opts, row_, col_) end
      end
    end)

  AddSignal("ls", function(alias, matches, retrieveonly)
      local matching_hists = {}
      if alias == nil or alias then
        for k, v in pairs(haliases) do
          if checknamematch(k, matches) then 
            if not retrieveonly then print(v.type, "\""..tostring(k).."\"") end
            table.insert(matching_hists, k)
          end
        end
      else
        for k, v in pairs(orruba_monitors) do
          if checknamematch(k, matches) then
            if not retrieveonly then print(v.type, "\""..tostring(k).."\"") end
            table.insert(matching_hists, k)
          end
        end
      end

      local result = #matching_hists > 0 and table.concat(matching_hists, "\\li") or "no results"
      SetSharedBuffer(result)
    end)

  local bufferfile = TFile(buffername and buffername or "live.root", "recreate")

  SetupStandardMonitors()

--  bufferfile:Write()

  orruba_monitors.h_monitor.hist:Draw("colz")

--  for _, h in pairs(orruba_monitors) do
--    if h.type == "1D" then h.hist:Draw()
--    else h.hist:Draw("colz") end
--  end

  local refresh_every = 20
  local records_read = 0
  local last_record_flush = 0

  local receiver_notified = false

  local first_evt_read, evts_read, missed_events, tot_evts = nil, 0, 0, 0

  local startWaitTime

  StartNewTask("ornl_buffering", "BufferORNLSenderData", GetTaskName(), address)

  local stat_term = MakeSlaveTerm({bgcolor="NavyBlue", title="ORNL DAQ Monitor", label="ornldaq monitor", fontstyle="Monospace", fontsize=10, geometry="100x15-0+0"})

  while CheckSignals() and not stopexec do
    if receiver_bufnum == 0 then
      if startWaitTime == nil then
        startWaitTime = GetClockTime()
      elseif ClockTimeDiff(startWaitTime, "second") > 10 then 
        startWaitTime = GetClockTime()
        stat_term:Write("\n10 seconds without receiving buffer count...\n")
      end
      sleep(0.1)
    elseif #buf_headers == 0 then
      if not receiver_notified then
        startWaitTime = nil
        SendSignalUnique("ornl_buffering", "sendrequest")
        receiver_notified = true
      else
        if startWaitTime == nil then
          startWaitTime = GetClockTime()
        elseif ClockTimeDiff(startWaitTime, "second") > 10 then 
          startWaitTime = GetClockTime()
          stat_term:Write("\n10 seconds without receiving data from receiver...\n")
          SendSignalUnique("ornl_buffering", "sendrequest")
        end
      end
      sleep(0.1)
    else
      for n=1, #buf_headers do
        if first_evt_read == nil then 
          first_evt_read = buf_headers[n].evtnum
        else
          tot_evts = buf_headers[n].evtnum - first_evt_read 
          if tot_evts ~= evts_read then
            missed_events = missed_events + (tot_evts - evts_read)
          end
        end

        bindata.record = ldfbuffers[n]
        bindata.cur_idx = 1

        local dummy, data = ReadNextRecord(buf_headers[n].bufsize)

        evts_read = evts_read + buf_headers[n].nevt

        for i, ev in ipairs(data) do
          for _, h in pairs(orruba_monitors) do
            h.fillfn(h.hist, ev)
          end
        end

        records_read = records_read + 1
      end

      if records_read-last_record_flush > refresh_every then
        stat_term:Write(string.format("Received %15d buffers... missed events: %5.1f %% - %10d\r", records_read, missed_events/tot_evts, missed_events))

        theApp:Update()

--        for k, v in pairs(orruba_monitors) do
--          v.hist:RefreshROOTObj()
--        end

--        bufferfile:Overwrite()
--        bufferfile:Flush()

        last_record_flush = records_read
      end

      bindata.record = nil
      receiver_notified = false
      buf_headers = {}
      ldfbuffers = {}
    end
  end

  stat_term:Write("\n")

  bufferfile:Close()
end

function StartMonitoringNetwork(address)
  MakeSyncSafe()

  local socket = require("lua_sockets")

  local receiver = socket.CreateClient("net", address)

  if not receiver then
    return
  end

  for _, h in pairs(orruba_monitors) do
    if h.type == "1D" then h.hist:Draw()
    else h.hist:Draw("colz") end
  end

  while CheckSignals() do
    local bytesread
    bytesread, bindata.record = receiver:WaitAndReceive(ldf_packetSize, true)
    bindata.cur_idx = 9

    if bytesread ~= ldf_packetSize then
      print("Did not read the amount of bytes expected:", bytesread, "instead of", ldf_packetSize)
    end

    local htype, data = ReadNextRecord(nil, true)

    if htype == "DATA" then
      for i, ev in ipairs(data) do
        for _, v in ipairs(ev) do
          for _, h in pairs(orruba_monitors) do
            h.fillfn(h.hist, v.channel, v.value)
          end
        end
      end

      theApp:Update()
    end

    receiver:WaitAndSendResponse("done")
  end

  MakeSyncSafe(false)
end