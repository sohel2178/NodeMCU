function split(str,sep)
    local array = {}
    local reg = string.format("([^%s]+)",sep)
    for mem in string.gmatch(str,reg) do
        table.insert(array, mem)
    end
    return array
end

function get_mac_address()
    mac_address = wifi.sta.getmac()
    mac_address = string.gsub(mac_address,":","")
    return mac_address
end

function set_state(data)
     local arr = split(data,"-")
     
     gpio.write(pin_one,arr[1])
     gpio.write(pin_two,arr[2])
     gpio.write(pin_three,arr[3])
     gpio.write(pin_four,arr[4])
end

function execute_gpio_command(sck,data)
    local array = split(data,"-")

    local pin = array[1]
    local cmd = array[2]

    if cmd == "ON" then
        gpio.write(pin, gpio.HIGH)
    else
        gpio.write(pin, gpio.LOW)
    end

    sck:send("*SP," .. get_mac_address() .. ",SAVE_DATA_AND_DELETE_COMMAND," .. data .. "#");
end



function process_response_from_socket(sck,data)
    local xVal = string.gsub(data,"*","")
    xVal = string.gsub(xVal,"#","")

    local array = split(xVal,",")

    local command = array[2]

    local state_data = array[3]

    print(command,state_data)

    if command == "LOGIN_SUCCESS" then
        set_state(state_data)
        start_writing_data(sck)
    elseif command == "CHANGE_STATE" then
        execute_gpio_command(sck,array[3])

    elseif command == "STATE_CHANGE" then
         set_state(state_data)    
    end
end

function get_config_from_internet()
    local url = "http://167.71.227.221:4665/api/devices" .. "\/" .. get_mac_address()
    local counter = 0;
    
    http.get(url,
        "Content-Type: application/json\r\n",
        function (code,data)
            if (code == 200) then
              print(code, data)
              parse_json_and_create_config_file_and_restart(data)
            else
         
              counter = counter+1

              if counter<5 then
                  print("HTTP request failed")
                  get_config_from_internet() 
              end
                          
            end
        end)
end

function parse_json_and_create_config_file_and_restart(data)
    local xVal = string.gsub(data,"}","")
    xVal = string.gsub(xVal,"{","")
    xVal = string.gsub(xVal,"\"","")
    local station_cfg={}
    local actual_ssid
    local actual_password

    for word in string.gmatch(xVal,'([^,]+)') do
    
        if string.find(word, "ssid:") ~=nil then
            local n = string.find(word, ":")
            actual_ssid = string.sub(word,(n+1))
            station_cfg.ssid = actual_ssid

        elseif string.find(word, "password:") ~=nil then
            local n = string.find(word, ":")
            actual_password = string.sub(word,(n+1))
            station_cfg.pwd = actual_password
        end        
    end

    fd = file.open("config.lua", "w+")

    if fd then
        fd.writeline('station_cfg={}')
        fd.writeline("station_cfg.ssid = " .. "\"" .. actual_ssid .. "\"")
        fd.writeline("station_cfg.pwd = " .. "\"" .. actual_password .. "\"")
        fd.close()
    end

--    Start from Begining
    start()

end

function connect_temporary_wifi()
    wifi.setmode(wifi.STATION)
    station_cfg={}
    station_cfg.ssid = "admin"
    station_cfg.pwd = "admin123"
    wifi.sta.config(station_cfg)
    wifi.sta.connect()
    
    local mytimer = tmr.create()
    mytimer:register(3000, tmr.ALARM_AUTO, function() 
            if(wifi.sta.getip()~=nil) then
                print("Temporary Wifi is Connected ") 
                gpio.write(pin_seven,gpio.HIGH)
                get_config_from_internet()
                
                mytimer:unregister()
            end
        end)
    mytimer:start()
end

function get_pin_state()
    return gpio.read(pin_one) .. gpio.read(pin_two) .. gpio.read(pin_three) .. gpio.read(pin_four)
end

function create_data_message()
    return "*SP," .. get_mac_address() .. ",DATA," .. get_pin_state() .. "#"
end

function start_writing_data(sck)
    timer = tmr.create()
    timer:register(30000, tmr.ALARM_AUTO, function()
        local message = create_data_message()
        print(message)
        sck:send(message)
    end)
    timer:start()
end


function send_login_request(sck)
    print("Build Login Request and Send")
    local login_command = "*SP," .. get_mac_address() .. ",LOGIN,0#"
    print(login_command)
    sck:send(login_command)
    
end


function connect_to_socket_server()
    client = net.createConnection(net.TCP,0)

    print(client)

    client:on("receive", function(sck, c)
        process_response_from_socket(sck,c)
        end)
    client:on("reconnection", function() 
        print("reconnection Called")
--        Low Indicator when Reconnect Called
        gpio.write(pin_eight,gpio.LOW)
        end)
    client:on("disconnection", function()
        print("disconnection Called") 
--        Low Indicator when Reconnect Called
        gpio.write(pin_eight,gpio.LOW)
        end)
    client:on("connection", function(sck)
--        start_writing_data(sck)
          send_login_request(sck)

--        High Indicator and Low Temp Wifi when Reconnect Called
          gpio.write(pin_seven,gpio.LOW)
          gpio.write(pin_eight,gpio.HIGH)
        
    end)
    client:connect(8547,"167.71.227.221")

end

function connect_actual_wifi(station_cfg)
    wifi.sta.config(station_cfg)
    wifi.sta.connect()
    
    local mytimer = tmr.create()
    mytimer:register(10000, tmr.ALARM_AUTO, function() 
            if(wifi.sta.getip()~=nil) then
                print("Actual Wifi is Connected ")

                
                
                connect_to_socket_server()
                
                mytimer:unregister()
            end
        end)
    mytimer:start()
end


function start()
    -- Setup GPIO PINS
    setup_gpio_pins()

    if file.exists("config.lua") then
        wifi.sta.disconnect()
        dofile("config.lua")
    --Call to Connect Actual Wifi
        connect_actual_wifi(station_cfg)
        print(station_cfg)
    else
        connect_temporary_wifi()
    end
end


function setup_gpio_pins()
    pin_one=1
    pin_two=2
    pin_three=3
    pin_four=4
    pin_seven=7
    pin_eight=8
    gpio.mode(pin_one, gpio.OUTPUT)
    gpio.mode(pin_two, gpio.OUTPUT)
    gpio.mode(pin_three, gpio.OUTPUT)
    gpio.mode(pin_four, gpio.OUTPUT)
    gpio.mode(pin_seven, gpio.OUTPUT)
    gpio.mode(pin_eight, gpio.OUTPUT)

    gpio.write(pin_seven,gpio.LOW)
    gpio.write(pin_eight,gpio.LOW)
end


start()


