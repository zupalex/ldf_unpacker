AddSignal("PrintMonitors", function() print("") for k, v in pairs(hmonitors) do print(k) end end)

AddSignal("ClearMonitor", function(monitor)
    if monitor == nil or hmonitors[monitor] == nil then
      print("No monitor or invalid monitor specified...")
      return
    end

    hmonitors[monitor].hist:Reset()
  end)

AddSignal("ClearMonitors", function()
    for k, v in pairs(hmonitors) do
      v.hist:Reset()
    end
  end)

AddSignal("AddMonitor", function(monitor_params, fillfn)
    AddMonitor({name = monitor_params.name, title = monitor_params.title, 
        xmin = monitor_params.xmin, xmax = monitor_params.xmax, nbinsx = monitor_params.nbinsx, 
        ymin = monitor_params.ymin, ymax = monitor_params.ymax, nbinsy = monitor_params.nbinsy}, 
      fillfn)

    if hmonitors[monitor_params.name].type == "1D" then hmonitors[monitor_params.name].hist:Draw()
    else hmonitors[monitor_params.name].hist:Draw("colz") end
  end)