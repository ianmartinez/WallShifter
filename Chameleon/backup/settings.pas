unit Settings;

{$mode objfpc}{$H+}

(*
  Handles the loading and saving of user settings.
*)
interface
  type TProgramMode =
      (pmNone, pmBattery, pmTime, pmWeatherConditions, pmWindSpeed, pmTemperature, pmHumidity, pmHeatIndex);

  type TProgramSettings = record
      Mode: TProgramMode;
      Interval: integer;
      State: string;
      WeatherStationName: string;
      RunAtStartup: boolean;
      ShowChameleonIsRunning: boolean;
       (* Flag if one of the args passes to the program called for
       an autostart and it hasn't been done yet. *)
      AutoStartNeeded: boolean;
  end;

  const Folders : array [0..6] of string =
      ('Battery', 'Time', 'WeatherConditions', 'WindSpeed', 'Temperature', 'Humidity', 'HeatIndex');

  const PercentageModes : array [0..11] of string =
      ('0%','1 to 9%','10 to 19%','20 to 29%','30 to 39%', '40 to 49%', '50 to 59%', '60 to 69%', '70 to 79%', '80 to 89%', '90 to 99%', '100%');

  const TimeModes : array [0..23] of string =
      ('12 AM', '1 AM', '2 AM', '3 AM', '4 AM', '5 AM', '6 AM', '7 AM', '8 AM', '9 AM', '10 AM', '11 AM',
      '12 PM', '1 PM', '2 PM', '3 PM', '4 PM', '5 PM', '6 PM', '7 PM', '8 PM', '9 PM', '10 PM', '11 PM');

  const WindSpeedModes : array [0..11] of string =
      ('0 MPH','1 to 9 MPH','10 to 19 MPH','20 to 29 MPH','30 to 39 MPH', '40 to 49 MPH', '50 to 59 MPH', '60 to 69 MPH',
      '70 to 79 MPH', '80 to 89 MPH', '90 to 99 MPH', '100+ MPH');

  const TemperatureModes : array [0..20] of string =
      ('<= -50°F', '-49 to -40°F', '-39 to -30°F', '-29 to -20°F', '-19 to -10°F', '-9 to -1°F', '0°F','1 to 9°F','10 to 19°F','20 to 29°F','30 to 39°F',
      '40 to 49°F', '50 to 59°F', '60 to 69°F', '70 to 79°F', '80 to 89°F', '90 to 99°F', '100 to 109°F', '110 to 119°F', '120 to 129°F', '>= 130°F');


  var ProgramSettings : TProgramSettings;

  function WriteSafeString(UnsafeString: string) : string;
  function GetAppLocation() : string;               
  function GetSettingsDir() : string;
  function GetLogFilePath() : string; 
  function GetWeatherStationsXmlPath() : string;  
  function GetWeatherDataXmlPath() : string;
  function GetImagePath(Key: string; Category: string) : string;  
  function GetThumbPath(Key: string; Category: string) : string; 
  function LoadSettings() : TProgramSettings;
  procedure SaveSettings(ProgramSettings: TProgramSettings);

  function GetCategoryName(const m: TProgramMode) : string; 
  function GetCategoryTitle(const m: TProgramMode) : string;

  function ConvertPercentage(const n: integer) : string;
  function ConvertSpeed(d: double) : string;
  function ConvertTemperature(n: integer) : string;

  function GetBattery() : string;
  function GetTime() : string;

implementation  
  uses
    Classes, SysUtils, Forms, IniFiles, typinfo, weather, Dialogs, windows;

  function WriteSafeString(UnsafeString: string) : string;
  var
    SafeString: string;
  begin
    SafeString := UnsafeString;
    SafeString := SafeString.Replace(' to ','To', [rfReplaceAll]);
    SafeString := SafeString.Replace('=','EqualTo', [rfReplaceAll]);
    SafeString := SafeString.Replace('/','And', [rfReplaceAll]);
    SafeString := SafeString.Replace('&','And', [rfReplaceAll]);
    SafeString := SafeString.Replace('<','LessThan', [rfReplaceAll]);
    SafeString := SafeString.Replace('>','MoreThan', [rfReplaceAll]);
    SafeString := SafeString.Replace('%','Percent', [rfReplaceAll]);
    SafeString := SafeString.Replace('-','Negative', [rfReplaceAll]);
    SafeString := SafeString.Replace('+','Plus', [rfReplaceAll]);
    SafeString := SafeString.Replace('°','Deg', [rfReplaceAll]);
    SafeString := SafeString.Replace(' ','', [rfReplaceAll]);

    result := SafeString;
  end;

  function GetAppLocation() : string;
  begin
    Result := ExtractFileDir(Application.ExeName);
  end;

  function GetSettingsDir() : string;
  var
    SettingsDir: String;
  begin
    SettingsDir := ExcludeTrailingPathDelimiter(GetUserDir) + PathDelim + 'ChameleonApp';

    if not DirectoryExists(SettingsDir) then begin
      CreateDir(SettingsDir);
    end;

    Result := SettingsDir;
  end;

  function GetImagePath(Key: string; Category: string) : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'Wallpapers' + PathDelim + Category + PathDelim + Key + '.jpg';
  end;

  function GetThumbPath(Key: string; Category: string) : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'Thumb' + PathDelim + Category + PathDelim + Key + '.jpg';
  end;
          
  function GetLogFilePath() : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'Chameleon.log';
  end;

  function GetWeatherStationsXmlPath() : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'WeatherStations.xml';
  end;

  function GetWeatherDataXmlPath() : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'WeatherData.xml';
  end;
  
  function GetSettingsFilePath() : string;
  begin
    Result := GetSettingsDir() + PathDelim + 'Settings.ini';
  end;

  function LoadSettings() : TProgramSettings;
  var                
    INI: TINIFile;
    ProgramSettings: TProgramSettings;
    SettingsPath: string;
  begin
    SettingsPath := GetSettingsFilePath;

    if fileexists(SettingsPath) then begin
      INI := TINIFile.Create(SettingsPath);

      try
        ProgramSettings.Mode := TProgramMode(INI.ReadInteger('Program', 'ProgramMode', 0));
        ProgramSettings.Interval := INI.ReadInteger('Program','Interval', 60);
        ProgramSettings.State := INI.ReadString('Weather', 'State', '');
        ProgramSettings.WeatherStationName := INI.ReadString('Weather', 'WeatherStationName', '');
        ProgramSettings.RunAtStartup := INI.ReadBool('Run', 'RunAtStartup', False);        
        ProgramSettings.ShowChameleonIsRunning := INI.ReadBool('Run', 'ShowChameleonIsRunning', True);
      finally
        INI.Free;
      end;
    end
    else begin
      ProgramSettings.Mode := pmNone;
      ProgramSettings.Interval := 60;
      ProgramSettings.State := '';
      ProgramSettings.WeatherStationName := '';      
        ProgramSettings.RunAtStartup := False;
        ProgramSettings.ShowChameleonIsRunning := True;
    end;

    Result := ProgramSettings;
  end;

  procedure SaveSettings(ProgramSettings: TProgramSettings);
  var
    INI: TINIFile;
    SettingsPath: string;
  begin
    SettingsPath := GetSettingsFilePath;
    INI := TINIFile.Create(SettingsPath);

    try
      INI.WriteInteger('Program', 'ProgramMode', integer(ProgramSettings.Mode));     
      INI.WriteInteger('Program', 'Interval', ProgramSettings.Interval);
      INI.WriteString('Weather', 'State', ProgramSettings.State);          
      INI.WriteString('Weather', 'WeatherStationName', ProgramSettings.WeatherStationName);
      INI.WriteBool('Run', 'RunAtStartup', ProgramSettings.RunAtStartup);
      INI.WriteBool('Run', 'ShowChameleonIsRunning', ProgramSettings.ShowChameleonIsRunning);

      INI.UpdateFile;
    finally
      INI.Free;
    end;
  end;

  function GetCategoryName(const m: TProgramMode) : string;
  begin
    case m of
      pmNone:
        Result := '';
      pmBattery:
        Result := 'Battery';
      pmTime:
        Result := 'Time';
      pmWeatherConditions:
        Result := 'WeatherConditions';
      pmWindSpeed:
        Result := 'WindSpeed';
      pmTemperature:
        Result := 'Temperature';
      pmHumidity:
        Result := 'Humidity';
      pmHeatIndex:
        Result := 'HeatIndex';
      else
        Result := '';
    end;
  end;

  function GetCategoryTitle(const m: TProgramMode) : string;
  begin
    case m of
      pmNone:
        Result := '';
      pmBattery:
        Result := 'Battery';
      pmTime:
        Result := 'Time';
      pmWeatherConditions:
        Result := 'Weather Conditions';
      pmWindSpeed:
        Result := 'Wind Speed';
      pmTemperature:
        Result := 'Temperature';
      pmHumidity:
        Result := 'Humidity';
      pmHeatIndex:
        Result := 'Heat Index';
      else
        Result := '';
    end;
  end;

  function ConvertPercentage(const n: integer) : string;
  begin
    case n of
      100:
        Result := '100%';
      90..99:
        Result := '90 to 99%';  
      80..89:
        Result := '80 to 89%'; 
      70..79:
        Result := '70 to 79%';
      60..69:
        Result := '60 to 69%';
      50..59:
        Result := '50 to 59%';
      40..49:
        Result := '40 to 49%';
      30..39:
        Result := '30 to 39%';
      20..29:
        Result := '20 to 29%';
      10..19:
        Result := '10 to 19%';  
      1..9:
        Result := '1 to 9%'; 
      0:
        Result := '0%';
      else
        Result := '0%';
    end;
  end;

  function ConvertSpeed(d: double) : string;
  var
    n: Integer;
  begin
    n := Round(d);

    case n of
      100..500:
        Result := '100+ MPH';
      90..99:
        Result := '90 to 99 MPH';
      80..89:
        Result := '80 to 89 MPH';
      70..79:
        Result := '70 to 79 MPH';
      60..69:
        Result := '60 to 69 MPH';
      50..59:
        Result := '50 to 59 MPH';
      40..49:
        Result := '40 to 49 MPH';
      30..39:
        Result := '30 to 39 MPH';
      20..29:
        Result := '20 to 29 MPH';
      10..19:
        Result := '10 to 19 MPH';
      1..9:
        Result := '1 to 9 MPH';
      0:
        Result := '0 MPH';
      else
        Result := '0 MPH';
    end;
  end;

  function ConvertTemperature(n: integer) : string;
  begin
    case n of
      130..500:
        Result := '>= 130°F';   
      120..129:
        Result := '120 to 129°F';
      110..119:
        Result := '110 to 119°F';
      100..109:
        Result := '100 to 109°F';
      90..99:
        Result := '90 to 99°F';
      80..89:
        Result := '80 to 89°F';
      70..79:
        Result := '70 to 79°F';
      60..69:
        Result := '60 to 69°F';
      50..59:
        Result := '50 to 59°F';
      40..49:
        Result := '40 to 49°F';
      30..39:
        Result := '30 to 39°F';
      20..29:
        Result := '20 to 29°F';
      10..19:
        Result := '10 to 19°F';
      1..9:
        Result := '1 to 9°F';
      0:
        Result := '0°F';   
      -9..-1:
        Result := '-9 to -1°F';    
      -19..-10:
        Result := '-19 to -10°F';
      -29..-20:
        Result := '-29 to -20°F';  
      -39..-30:
        Result := '-39 to -30°F';
      -49..-40:
        Result := '-49 to -40°F';
      -500..-50:
        Result := '<= -50°F';
      else
        Result := '0°F';
    end;
  end;

  function GetBattery() : string;
  var
    PowerStatus: TSystemPowerStatus;
    Percentage: integer;
  begin
    Percentage := 0;

    if GetSystemPowerStatus(PowerStatus) then begin
      Percentage := integer(PowerStatus.BatteryLifePercent);
    end;

    Result := ConvertPercentage(Percentage);
  end;

  function GetTime() : string;
  begin
    DefaultFormatSettings.TimeAMString := 'AM';
    DefaultFormatSettings.TimePMString := 'PM';
    Result := formatdatetime('h ampm', Now);
  end;
end.
