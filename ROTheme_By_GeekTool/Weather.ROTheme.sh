#!/usr/bin/env -S-P/usr/local/bin:/usr/bin:${PATH} php
<?php
ini_set('date.timezone','Asia/Shanghai');
class  RoThemes {
    public static $_tmp_file =  '/tmp/.RoThemes';
    public static $_root =  false;
    public static $_time = false;

    public static function time(){
        if(self::$_time === false){
            self::$_time = time();
        }
        return self::$_time;
    }

    public static function path($path=''){
        if(self::$_root === false){
            self::$_root = dirname($path).'/';
        }
        return self::$_root;
    }

    public static function curl_https($url, $data=array(), $timeout=10){
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // 跳过证书检查
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, true); // 从证书中检查SSL加密算法是否存在
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array());
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
        $response = curl_exec($ch);
        if(curl_errno($ch)){
            curl_close($ch);
            return false;
        }
        curl_close($ch);
        return $response;
    }

    public static function formatDate($day,$weekday){
        $array  = array(
            1 => '星期一',
            2 => '星期二',
            3 => '星期三',
            4 => '星期四',
            5 => '星期五',
            6 => '星期六',
            7 => '星期天'
        );
        return substr($day,0,4).'年'.substr($day,5,2).'月'.substr($day,7).'日, '.$array[intval($weekday)];
    }

    public static function getWeatherDatas($area='广州'){
        $data = array();
        $readState = 0;
        /* $readState
        0   : 初始化
        -1  : 过期(默认1小时),每1小时刷新一次.
        1   : 正常下载数据并返回
        2   : 旧数据,但没有超过今天的时间
        */
        if(file_exists(self::$_tmp_file)){
            $data = unserialize(file_get_contents(self::$_tmp_file));
            $time = (isset($data['time']))? intval($data['time']):0;
            $readState = (self::time() > ($time + (1)))?-1:1;
        }
        if($readState<=0){
            $data = array();
            if($res = self::saveWeatherDatas($area)){
                $data = $res;
                $readState = 1;
            }elseif(!empty($data)){
                $max_day = (isset($data['max_day']))? intval($data['max_day']):0;
                if($max_day >= intval(date('Ymd',self::time()))){
                    $readState = 1;
                }
            }
        }
        $emptyIconPath = self::path().'images/weather/empty.png';
        $icons = array(
            '.ROTheme.Weather.now.png' => $emptyIconPath,
        );
        for($i=1;$i<=7;$i++){
            $icons['.RoThemes.Weather.'.$i.'.day.png'] = $emptyIconPath;
            $icons['.RoThemes.Weather.'.$i.'.night.png'] = $emptyIconPath;
        }
        if($readState>1){
            unset($data['now']);
        }else{
            $icons['.RoThemes.Weather.now.png'] = self::$_root.'images/weather/'.$data['now']['icon'];
        }
        $dayInt = intval(date('Ymd',self::time()));
        $index = 1;
        foreach ($data['days'] as $key => $value) {
            if($dayInt>intval($key))  unset($data['days'][$key]);
            else{
                $icons['.RoThemes.Weather.'.$index.'.day.png'] = self::$_root.'images/weather/day/'.$value['icons']['day'].'.png';
                $icons['.RoThemes.Weather.'.$index.'.night.png'] = self::$_root.'images/weather/night/'.$value['icons']['night'].'.png';
                echo self::formatDate($key,$value['weekday'])."\n";
                echo "日间:      ".$value['weather']['day']."\n";
                echo "夜间:      ".$value['weather']['night']."\n\r";
                $index++;
            }
        }
        foreach ($icons as $key => $value) {
            copy($value,'/tmp/'.$key);
        }
    }

    public static function saveWeatherDatas($area='广州'){
        // echo 'status network...';
        $url = 'https://route.showapi.com/9-2';
        $data = array(
            'area' => $area,
            //'areaid' => '',
            'need3HourForcast' => 0,
            'needAlarm' => 1,
            'needHourData' => 0,
            'needIndex' => 0,
            'needMoreDay' => 1,
            'showapi_timestamp' => date(YmdHis,self::time()),
            'showapi_appid' => '13960',
            'showapi_sign' => '9b1c9d0bf2b248fc925bcdab31ccfb06',
        );
        if($response = self::curl_https($url, $data)){
            $result  = json_decode($response,true);
            $_datas = array();
            $_datas['max_day'] = 0;
            if(0 == intval($result['showapi_res_code'])){
                $datas = $result['showapi_res_body'];
                $cityInfo = $datas['cityInfo'];
                $latitude = $cityInfo['latitude']; //纬度
                $longitude = $cityInfo['longitude']; //经度
                $city = $cityInfo['c3']; //城市中文名`
                $now = $datas['now'];
                $now_weather = $now['weather'].', 气温:'.$now['temperature'].', 湿度:'.$now['sd'].', 风向:'.$now['wind_direction'].', 风力:'.$now['wind_power'].', 指数:'.$now['aqi'].'<'.$now['temperature_time'].'>';;
                $now_pm = $now['aqiDetail']['pm2_5'].'<'.$now['aqiDetail']['quality'].', '.$now['aqiDetail']['primary_pollutant'].'>';
                for($i=1;$i<=7;$i++){
                    $_day = $datas['f'.$i];
                    $day = $_day['day'];
                    if(intval($day)>$_datas['max_day']) {
                        $_datas['max_day'] = $day;
                    }
                    $_datas['days'][$day] = array(
                        'weather' => array(
                            'day' => $_day['day_air_temperature']."℃, ".$_day['day_weather'].", ".$_day['day_wind_direction'].", ".$_day['day_wind_power'],
                            'night' => $_day['night_air_temperature']."℃, ".$_day['night_weather'].", ".$_day['night_wind_direction'].", ".$_day['night_wind_power']
                        ),
                        'sun_begin_end' => $_day['sun_begin_end'],
                        "weekday"=>  $_day['weekday'],
                        'icons' => array(
                            'day' => strval($_day['day_weather_code']),
                            'night' => strval($_day['night_weather_code']),
                        ),
                    );
                }
                $nowIcon = 'day/'.$now['weather_code'].'.png';
                if(preg_match('/(night|day)\/([0-9]+\.png)$/',$s,$matches)){
                    $nowIcon=$matches[0];
                }
                $_datas['now'] = array (
                    'weather' =>  $now_weather,
                    'pm' => $now_pm,
                    'icon' => $nowIcon
                );
                $_datas['updatetime'] = $datas['time'];
                $_datas['time'] = self::time();
                file_put_contents(self::$_tmp_file,serialize($_datas));
                return $_datas;
            }
        }
        return false;
    }
}

RoThemes::path($argv[0]);
RoThemes::$_tmp_file = '/tmp/.RoThemes.weather';
RoThemes::getWeatherDatas();



