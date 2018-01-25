print(wifi.sta.getip())
--nil
wifi.setmode(wifi.STATION)
station_cfg={}
station_cfg.ssid="xiaorenren"
station_cfg.pwd="*****"
wifi.sta.config(station_cfg)
print(wifi.sta.getip())
--192.168.18.110
-- a simple http server

require("telnet_srv")

local sensors_stat = "-1"
local send_count = 0
local recv_count = 0

local pm25 = -1
local hcho = -1
local co2 = -1
local Temp = -1
local Hum = -1

function calcAQI(pNum)
    --local clow = {0,15.5,40.5,65.5,150.5,250.5,350.5}
    --local chigh = {15.4,40.4,65.4,150.4,250.4,350.4,500.4}
    --local ilow = {0,51,101,151,201,301,401}
    --local ihigh = {50,100,150,200,300,400,500}
    local ipm25 = {0,35,75,115,150,250,350,500}
    local laqi = {0,50,100,150,200,300,400,500}
    local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
    --print(table.getn(chigh))
    aqiLevel = 8
    for i = 1,table.getn(ipm25),1 do
         if(pNum<ipm25[i])then
              aqiLevel = i
              break
         end
    end
    --aqiNum = (ihigh[aqiLevel]-ilow[aqiLevel])/(chigh[aqiLevel]-clow[aqiLevel])*(pNum-clow[aqiLevel])+ilow[aqiLevel]
    aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])+laqi[aqiLevel-1]
    return math.floor(aqiNum),result[aqiLevel-1]
end

function resolveData(data)
    if(((string.byte(data,1)==0x42) and(string.byte(data,2)==0x4d))) then
         pm25 = (string.byte(data,5)*256+string.byte(data,6))
         hcho = (string.byte(data,10)*256+string.byte(data,11))/100
         co2 = (string.byte(data,13)*256+string.byte(data,14))
         Temp = (string.byte(data,15)*256+string.byte(data,16))/10
         Hum = (string.byte(data,17)*256+string.byte(data,18))/10
         res = ""
         res = res.."<p>dust:"..pm25.."</p>"
         res = res.."<p>CO2:"..co2.."</p>"
         res = res.."<p>HCHO:"..hcho.."</p>"
         res = res.."<p>H1:"..Hum.."</p>"
         res = res.."<p>T1:"..Temp.."</p>"
         sensors_stat = res 
    else
        recv_count = recv_count - 1
        sensors_stat = ""..recv_count      
    end
end

--require("SensorDetector")
--require("LeweiMqtt")
--require("run")


gpio.mode(4,gpio.OUTPUT)
gpio.write(4,gpio.HIGH)

uart.setup(0,9600,8,0,1,0)

tmr.alarm(0,5000, tmr.ALARM_AUTO, function()
    uart.write(0,0x42,0x4D,0xAB,0x00,0x00,0x01,0x3A);
    send_count = send_count + 1
end)

local uartTimer = tmr.create()
local rcv = ""

uart.on("data", 0,
     function(data)
        uartTimer:register(10, tmr.ALARM_SINGLE, function()
        resolveData(rcv)
        uartTimer:stop()
        rcv = ""
        end)
        rcv = rcv..data
        uartTimer:start()
      end, 0)

require("LeweiMqtt")

srv=net.createServer(net.TCP) 
srv:listen(80,function(conn) 
    conn:on("receive",function(conn,payload) 
    --print(payload) 
    --sensors = LeweiMqtt.getSensorValues()
    --sensors_str = ""
    --for i,v in pairs(sensors) do 
    --    sensors_str = sensors_str..i..":"..v.."\n"
    --end
    conn:send("<h1> This is xiaohao's 7 nodemcu!</h1><h2>"..sensors_stat.."</h2><h3>send_count="..send_count.."!</h3>")
    end) 
end)


LeweiMqtt.init("f1afc*****","02")
LeweiMqtt.connect()

sendTimer = tmr.create()
sendTimer:register(60000, tmr.ALARM_AUTO, function() 

LeweiMqtt.appendSensorValue("dust",pm25)
aqi,result = calcAQI(pm25)
LeweiMqtt.appendSensorValue("AQI",aqi)
LeweiMqtt.appendSensorValue("CO2",co2)
LeweiMqtt.appendSensorValue("HCHO",hcho)
LeweiMqtt.appendSensorValue("H1",Hum)
LeweiMqtt.appendSensorValue("T1",Temp)

sensors = LeweiMqtt.getSensorValues()
count = 0
for i,v in pairs(sensors) do
          count = count + 1
end

index = 0
for i,v in pairs(sensors) do
     index = index + 1
     print(i,v,index,count)
     if(index == count) then
     --print("S")
          LeweiMqtt.sendSensorValue(i,v)
     else
     --print("A")
          LeweiMqtt.appendSensorValue(i,v)
     end
end
end)
sendTimer:start()
