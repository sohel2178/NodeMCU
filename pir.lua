print("Hello World")

pin_one = 1
pin_two =2
gpio.mode(pin_two, gpio.OUTPUT)
gpio.mode(3, gpio.OUTPUT)
gpio.write(3,0)

my_str = ""


local mytimer = tmr.create()
mytimer:register(1000, tmr.ALARM_AUTO, function() 
         print("Actual Wifi is Connected ")
         my_str = my_str .. gpio.read(pin_one)
         print(my_str)

         if string.len(my_str)>=10 then
            my_str = string.sub(my_str,-10)
         end

         if string.find(my_str,"1") ~= nil then
            gpio.write(pin_two,gpio.HIGH)
         else
            gpio.write(pin_two,gpio.LOW)
         end
         
    end)
mytimer:start()



enduser_setup.start(
  function()
    print("Connected to wifi as:" .. wifi.sta.getip())
    local sta_config = wifi.sta.getconfig(true)
    sta_config.save = true
    sta_config.got_ip_cb=start_service
    wifi.sta.config(sta_config)
  end,
  function(err, str)
    print("enduser_setup: Err #" .. err .. ": " .. str)
  end,
  print -- Lua print function can serve as the debug callback
);