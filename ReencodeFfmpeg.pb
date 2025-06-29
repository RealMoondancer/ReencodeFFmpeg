XIncludeFile "ReencodeFfmpeg.pbf" ; Put code from ReencodeFfmpeg.pbf here during compilation (from Form Editor)

#CurrentVersion = 5
Global ConfigFile.s = GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\config.txt"
Global NewMap Config.s()

Macro Debug(Text)
  CompilerIf #PB_Compiler_Debugger
    Debug "[" + fname + "] " + Text
  CompilerEndIf
EndMacro

OpenWindow_0() ; Start and initialize Window
HideGadget(wait_text, #True) ; Hide the Please wait text
HideGadget(download_text, #True)
SetGadgetText(wait_text, "Please wait for FFmpeg to finish")
DisableGadget(advanced_cmd, #True)
HideGadget(cancel_download, #True)

SetGadgetState(width_spin, -1)
SetGadgetState(height_spin, -1)
SetGadgetState(fps_spin, -1)
SetGadgetState(start_spin, -1)
SetGadgetState(duration_spin, -1)
SetGadgetText(width_spin, "-1")
SetGadgetText(height_spin, "-1")
SetGadgetText(fps_spin, "-1")
SetGadgetText(start_spin, "-1")
SetGadgetText(duration_spin, "-1")

Procedure LoadConfigFile(filename.s)
  Protected fname.s = "LoadConfigFile"
  Debug("Running")
  If ReadFile(0, filename)
    While Eof(0) = 0
      line.s = Trim(ReadString(0))
      ; Skip blank lines or comments
      If Len(line) > 0 And Left(line, 1) <> ";"  
        pos.i = FindString(line, "=", 1)
        If pos > 0
          key.s = Trim(Left(line, pos - 1))
          val.s = Trim(Mid(line, pos + 1))
          ; Store under “Section|Key”
          Config(key) = val
        EndIf
      EndIf
    Wend
    CloseFile(0)
  Else
    Debug("Cannot open config file: " + filename)
  EndIf
EndProcedure

Procedure.s GetConfigValue(key.s, defaultValue.s)
  Protected fname.s = "GetConfigValue"
  Debug("Running")
  If FindMapElement(Config(), key)
    ProcedureReturn Config(key)
  Else
    ProcedureReturn defaultValue
  EndIf
EndProcedure

Procedure SaveConfigFile(filename.s)
  Protected fname.s = "SaveConfigFile"
  Debug("Running")
  file = CreateFile(#PB_Any, filename)
  ResetMap(Config())
  While NextMapElement(Config())
    Debug(MapKey(Config()) + "=" + Config())
    WriteStringN(file, MapKey(Config()) + "=" + Config())
  Wend
  CloseFile(file)
EndProcedure

Procedure.s AddToFilename(path.s, insert.s)
  Protected slashPos.i = 0
  Protected dotPos.i   = 0
  Protected i.i

  ; 1) Find last slash or back-slash
  For i = Len(path) To 1 Step -1
    Select Mid(path, i, 1)
      Case "\", "/"
        slashPos = i
        Break
    EndSelect
  Next

  ; 2) Find last dot after that slash
  For i = Len(path) To slashPos + 1 Step -1
    If Mid(path, i, 1) = "." 
      dotPos = i
      Break
    EndIf
  Next

  ; 3) Rebuild path with insert before extension
  If dotPos > slashPos
    ProcedureReturn Left(path, dotPos - 1) + insert + Mid(path, dotPos)
  Else
    ; no extension found → append at end
    ProcedureReturn path + insert
  EndIf
EndProcedure

Procedure SelectInput(EventType) ; Open a select Dialouge
  Protected fname.s = "SelectInput"
  Debug("Running")
  file$ = OpenFileRequester("Select input file", "", "Video Files|*.webm;*.mkv;*.flv;*.vob;*.ogv;*.ogg;*.drc;*.gif;*.gifv;*.mng;*.avi;*.mts;*.m2ts;*.ts;*.mov;*.qt;*.wmv;*.yuv;*.rm;*.rmvb;*.viv;*.asf;*.amv;*.mp4;*.m4p;*.m4v;*.mpg;*.mp2;*.mpeg;*.mpe;*.mpv;*.m2v;*.m4v;*.svi;*.3gp;*.3g2;*.mxf;*.roq;*.nsv;*.flv;*.f4v;*.f4p;*.f4a;*.f4b", 0)
  If file$ ; If file$   -> A file was selected and not clicked on cancel
  Else
    Debug("No file selected")
    ProcedureReturn
  EndIf
  
  res.q = FileSize(file$) ; Check if the file exists by checking its size
  Debug(res)
  If res = -1 ; File not Found
    MessageRequester("Error", "The selected file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2 ; File is directory
    MessageRequester("Error", "The selected file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  Debug("Setting in to " + file$)
  SetGadgetText(inputFile, file$) ; Set text of input field to selected file
  SetGadgetText(outputFile, AddToFilename(file$, "_reencode"))
EndProcedure

Procedure SelectOutput(EventType) ; Open a select dialouge
  Protected fname.s = "SelectOutput"
  Debug("Running")
  in$ = GetGadgetText(inputFile) ; Get the path of the selected input file to make this the preselected file in the save dialouge
  Debug("Intext: " + in$)
  
  file$ = SaveFileRequester("Select output file", in$, "Video Files|*.webm;*.mkv;*.flv;*.vob;*.ogv;*.ogg;*.drc;*.gif;*.gifv;*.mng;*.avi;*.mts;*.m2ts;*.ts;*.mov;*.qt;*.wmv;*.yuv;*.rm;*.rmvb;*.viv;*.asf;*.amv;*.mp4;*.m4p;*.m4v;*.mpg;*.mp2;*.mpeg;*.mpe;*.mpv;*.m2v;*.m4v;*.svi;*.3gp;*.3g2;*.mxf;*.roq;*.nsv;*.flv;*.f4v;*.f4p;*.f4a;*.f4b", 0)
  If file$
  Else
    Debug("No file selected")
    ProcedureReturn
  EndIf
  Debug("Setting out to " + file$)
  SetGadgetText(outputFile, file$)
EndProcedure

Procedure RemoveFFmpeg(Event)
  Protected fname.s = "RemoveFFmpeg"
  Debug("Running")
  If DeleteFile(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffmpeg.exe")
    If Not Event=-1
      MessageRequester("Information", "Successfully deleted FFmpeg", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
    EndIf
  Else
    If Not Event=-1
      MessageRequester("Error", "Failed to delete FFmpeg", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    EndIf
  EndIf
  If DeleteFile(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffprobe.exe")
    If Not Event=-1
      MessageRequester("Information", "Successfully deleted FFprobe", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
    EndIf
  Else
    If Not Event=-1
      MessageRequester("Error", "Failed to delete FFprobe", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    EndIf
  EndIf
EndProcedure

Procedure RemoveConfig(Event)
  Protected fname.s="RemoveConfig"
  Debug("Running")
  If DeleteFile(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\config.txt")
    MessageRequester("Information", "Successfully deleted config", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
  Else
    MessageRequester("Error", "Failed to delete config", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
EndProcedure

Procedure DownloadFile(url.s, filename.s, name.s, showDialouge.b)
  Protected fname.s = "DownloadFile"
  Debug("Running")
  Debug(name)
  Debug(url)
  Debug(filename)
  name = "[" + name + "] "
  HttpRequest = HTTPRequest(#PB_HTTP_Get, url, "", #PB_HTTP_HeadersOnly)
  Debug("Response: " + HTTPInfo(HTTPRequest, #PB_HTTP_Response))
  Debug("StatusCode: " + HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode))
  headers$ = HTTPInfo(HTTPRequest, #PB_HTTP_Headers)
  Debug("Headers: " + headers$)
  FinishHTTP(HTTPRequest)
  ContentSize = 1
  If CreateRegularExpression(0, "^[\w\W]*Content-Length: (\d+)[\w\W]*$")
    If ExamineRegularExpression(0, headers$)
      While NextRegularExpressionMatch(0)
        ContentSize = Val(RegularExpressionGroup(0, 1))
        Debug("Size is " + ContentSize)
      Wend
    EndIf

  Else
    Debug(RegularExpressionError())
  EndIf
  
  Download = ReceiveHTTPFile(url, filename, #PB_HTTP_Asynchronous)
  If Download
    HideGadget(download_text, #False)
    HideGadget(cancel_download, #False) 
    Repeat
      Progress = HTTPProgress(Download)
      Select Progress
        Case #PB_HTTP_Success
          Size = FinishHTTP(Download)
          Debug(name + "Download finished (size: " + size + ")")
          If showDialouge
            MessageRequester("Information", name + "Download finished", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
          Else
            SetGadgetText(download_text, name + "Download finished")
            WindowEvent()
            Delay(1000)
          EndIf
          HideGadget(download_text, #True)
          HideGadget(cancel_download, #True)
          ProcedureReturn #True

        Case #PB_HTTP_Failed
          Debug(name + "Download failed")
          FinishHTTP(Download)
          If showDialouge
            MessageRequester("Error", name + ~"Download failed\n\n(" + url + ")", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
          Else
            SetGadgetText(download_text, name + ~"Download failed\n\n(" + url + ")")
            WindowEvent()
            Delay(1000)
          EndIf
          HideGadget(download_text, #True)
          HideGadget(cancel_download, #True)
          DeleteFile(filename)
          ProcedureReturn #False

        Case #PB_HTTP_Aborted
          Debug(name + "Download aborted")
          FinishHTTP(Download)
          If showDialouge
            MessageRequester("Error", name + ~"Download aborted\n\n(" + url + ")", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
          Else
            SetGadgetText(download_text, name + ~"Download aborted\n\n(" + url + ")")
            WindowEvent()
            Delay(1000)
          EndIf
          HideGadget(download_text, #True)
          HideGadget(cancel_download, #True)
          DeleteFile(filename)
          ProcedureReturn #False
          
        Default
          prg.d = Round((Progress/ContentSize)*10000, #PB_Round_Up) / 100 ; xx.xx% cap to 2 digits after .
          SetGadgetText(download_text, name + "Downloading: " + prg + "% (" + Progress + "/" + ContentSize + ")")
          event = WindowEvent()
          Select event
            Case #PB_Event_Gadget
              Select EventGadget()     
                Case cancel_download
                  AbortHTTP(Download)
              EndSelect
          EndSelect
       
      EndSelect
      
      Delay(50) ; Don't stole the whole CPU
    ForEver
      
  Else
    If showDialouge
      MessageRequester("Error", name + ~"Download failed\n\n(" + url + ")", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    Else
      SetGadgetText(download_text, name + ~"Download failed\n\n(" + url + ")")
      WindowEvent()
      Delay(1000)
    EndIf
    DeleteFile(filename)
    ProcedureReturn #False
  EndIf
EndProcedure

Procedure EnsureFFmpeg(Event)
  Protected fname.s = "EnsureFFmpeg"
  Debug("Running")
  Debug("Checking FFmpeg")
  ffpath$ = GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\"
  Debug(ffpath$)
  res.q = FileSize(ffpath$)
  If res = -1
    Debug("Directory doesn't exist, creating...")
    result = CreateDirectory(ffpath$)
    If result = 0
      MessageRequester("Error", "Failed to create " + ffpath$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn #False
    EndIf
  EndIf
  ffmpath$ = ffpath$ + "ffmpeg.exe"
  Debug("Checking " + ffmpath$)
  res.q = FileSize(ffmpath$)
  Debug(res)
  ffppath$ = ffpath$ + "ffprobe.exe"
  Debug("Checking " + ffppath$)
  res2.q = FileSize(ffppath$)
  Debug(res2)
  If res = -1 Or res2 = -1
    Debug("Doesn't exist, trying to download")
    result = MessageRequester("Error", ~"FFmpeg couldn't be found. Download it automatically?\nA small 7zip executable will be downloaded alongside it to extract the 7z archive.\n\nIt will be saved to\n" + ffpath$, #PB_MessageRequester_Warning | #PB_MessageRequester_YesNo)
    RemoveFFmpeg(-1)
    If result = #PB_MessageRequester_No
      ProcedureReturn #False
    EndIf
    
    ; Download 7z
    If Not DownloadFile("https://www.7-zip.org/a/7zr.exe", ffpath$ + "7zr.exe", "7zr", #False)
      MessageRequester("Error", "Failed to download 7zip, stopping download.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn #False
    EndIf
    
    ; Download FFmpeg
    If Not DownloadFile("https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z", ffpath$ + "ffmpeg.7z", "FFmpeg", #False)
      MessageRequester("Error", "Failed to download ffmpeg.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      DeleteFile(ffpath$ + "7zr.exe")
      ProcedureReturn #False
    EndIf
    
    ; Extract Files
    HideGadget(download_text, #False)
    SetGadgetText(download_text, "Please wait for 7zip to finish extracting.")
    args$ = "e ffmpeg.7z ffmpeg.exe ffprobe.exe -r"
    sevenzzip = RunProgram(ffpath$ + "7zr.exe", args$, ffpath$, #PB_Program_Wait)
    Output$ = ""
    Error$ = ""
    If sevenzip
      Debug("7z running")
    Else
      Debug("7z failed to start")
    EndIf
    HideGadget(download_text, #True)
    
    DeleteFile(ffpath$ + "ffmpeg.7z")
    DeleteFile(ffpath$ + "7zr.exe")
    
    Debug("Checking " + ffmpath$)
    res3.q = FileSize(ffmpath$)
    Debug(res3)
    Debug("Checking " + ffppath$)
    res4.q = FileSize(ffppath$)
    Debug(res4)
    
    If (Not res3=-1) And (Not res4=-1)
      If Not Event=-1
        MessageRequester("Information", "FFmpeg downloaded successfully.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
      EndIf
    Else
      MessageRequester("Error", "Failed to download FFmpeg.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    EndIf
    
  Else
    Debug(Event)
    If Not Event=-1
      MessageRequester("Information", "FFmpeg available at " + ffpath$, #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
    EndIf
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure About(Event)
  Protected fname.s = "About"
  Debug("Running")
  MessageRequester("About", ~"(c) 2025 Moondancer Productions (Ditin2)\n\nMade using PureBasic 6.20 and FFmpeg 2025-05-26-git-43a69886b2-essentials_build-www.gyan.dev", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure PCRELicense(Event)
  Protected fname.s = "PCRELicense"
  Debug("Running")
  MessageRequester("PCRE License", ~"PCRE LICENCE\n------------\n\nPCRE is a library of functions To support regular expressions whose syntax\nand semantics are As close As possible To those of the Perl 5 language.\n\nRelease 7 of PCRE is distributed under the terms of the \"BSD\" licence, As\nspecified below. The documentation For PCRE, supplied in the \"doc\"\ndirectory, is distributed under the same terms As the software itself.\n\nThe basic library functions are written in C And are freestanding. Also\nincluded in the distribution is a set of C++ wrapper functions.\n\n\nTHE BASIC LIBRARY FUNCTIONS\n---------------------------\n\nWritten by:       Philip Hazel\nEmail local part: ph10\nEmail domain:     cam.ac.uk\n\nUniversity of Cambridge Computing Service,\nCambridge, England.\n\nCopyright (c) 1997-2007 University of Cambridge\nAll rights reserved.\n\n\nTHE C++ WRAPPER FUNCTIONS\n-------------------------\n\nContributed by:   Google Inc.\n\nCopyright (c) 2007, Google Inc.\nAll rights reserved.\n\n\nTHE \"BSD\" LICENCE\n-----------------\n\nRedistribution And use in source And binary forms, With Or without\nmodification, are permitted provided that the following conditions are met:\n\n    * Redistributions of source code must retain the above copyright notice,\n      this List of conditions And the following disclaimer.\n\n    * Redistributions in binary form must reproduce the above copyright\n      notice, this List of conditions And the following disclaimer in the\n      documentation And/Or other materials provided With the distribution.\n\n    * Neither the name of the University of Cambridge nor the name of Google\n      Inc. nor the names of their contributors may be used To endorse Or\n      promote products derived from this software without specific prior\n      written permission.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS And CONTRIBUTORS \"As IS\"\nAND ANY EXPRESS Or IMPLIED WARRANTIES, INCLUDING, BUT Not LIMITED To, THE\nIMPLIED WARRANTIES OF MERCHANTABILITY And FITNESS For A PARTICULAR PURPOSE\nARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER Or CONTRIBUTORS BE\nLIABLE For ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, Or\nCONSEQUENTIAL DAMAGES (INCLUDING, BUT Not LIMITED To, PROCUREMENT OF\nSUBSTITUTE GOODS Or SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS\nINTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN\nCONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)\nARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE\nPOSSIBILITY OF SUCH DAMAGE.\n\nEnd", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure.s BuildFFmpegArgs()
  Protected fname.s = "BuildFFmpegArgs"
  Debug("Running")
  filters$ = ""
  preset$= ""
  videofilter$ = ""
  start$ = ""
  duration$ = ""
  
  ; ----------------- Audio Filter -----------------
  If GetGadgetState(normalize)
    ; If normalize is checked, add the audio filter
    filters$ = ~"-filter:a \"dynaudnorm=p=0.9:s=5\" "
  EndIf
  
  ; ----------------- Processing Preset -----------------
  If GetGadgetState(veryslow)
    preset$ = "-preset veryslow "
  ElseIf GetGadgetState(slower)
    preset$ = "-preset slower "
  ElseIf GetGadgetState(slow)
    preset$ = "-preset slow "
  ElseIf GetGadgetState(medium)
    preset$ = "-preset medium "
  ElseIf GetGadgetState(fast)
    preset$ = "-preset fast "
  ElseIf GetGadgetState(faster)
    preset$ = "-preset faster "
  ElseIf GetGadgetState(veryfast)
    preset$ = "-preset veryfast "
  ElseIf GetGadgetState(superfast)
    preset$ = "-preset superfast "
  ElseIf GetGadgetState(ultrafast)
    preset$ = "-preset ultrafast "
  EndIf
  
  ; ----------------- Resizing/Cropping -----------------
  height = GetGadgetState(height_spin)
  width = GetGadgetState(width_spin)
  Debug(height)
  Debug(width)
  If height <> -1 Or width <> -1
    videofilter$ + "-vf scale=" + Str(width) + ":" + Str(height) + " "
  EndIf
  
  ; ----------------- FPS Changing -----------------
  fps = GetGadgetState(fps_spin)
  If fps <> -1
    videofilter$ + "-vf fps=" + Str(fps) + " "
  EndIf
  
  ; ----------------- Cutting -----------------
  s$ = GetGadgetText(start_spin)
  d$ = GetGadgetText(duration_spin)
  If s$ <> "-1" And d$ <> "-1"
    start$ + "-ss " + s$ + " "
    If GetGadgetState(select_end)
      duration$ + "-to " + d$ + " "
    Else
      duration$ + "-t " + d$ + " "
    EndIf
  EndIf
  
  command$ = ~"-y -hide_banner -i \"{infile}\" " + start$ + duration$ + preset$ + filters$ + videofilter$ + ~"\"{outfile}\""
  Debug("FFmpeg args: " + command$)
  ProcedureReturn command$
EndProcedure

Procedure.s ConvertSecondsToTimeString(totalSeconds.f)
  Protected h.l, m.l, s.l, hund.l
  Protected rem.f
  Protected hoursStr.s, minutesStr.s, secondsStr.s, hundStr.s

  ; Break down into hours, minutes, seconds, and hundredths
  h   = Int(totalSeconds / 3600)          ; hours
  rem = totalSeconds - h * 3600            ; remainder
  m   = Int(rem / 60)                      ; minutes
  rem = rem - m * 60
  s   = Int(rem)                           ; whole seconds
  hund = Int((rem - s) * 100 + 0.5)        ; hundredths, rounded

  ; Handle any rounding overflow
  If hund >= 100
    hund = hund - 100
    s    = s + 1
  EndIf
  If s >= 60
    s = s - 60
    m = m + 1
  EndIf
  If m >= 60
    m = m - 60
    h = h + 1
  EndIf

  ; Build zero-padded components
  hoursStr   = Right("0" + Str(h),   2)
  minutesStr = Right("0" + Str(m),   2)
  secondsStr = Right("0" + Str(s),   2)
  hundStr    = Right("0" + Str(hund),2)

  ProcedureReturn hoursStr + ":" + minutesStr + ":" + secondsStr + "." + hundStr
EndProcedure

Procedure StartReencode(EventType)
  Protected fname.s = "StartReencode"
  Debug("Running")
  Debug("Start Reencode event")
  Debug("Normalize audio: " + GetGadgetState(normalize))
  infile$ = GetGadgetText(inputFile) ; Same stuff as in SelectInput()
  Debug("Input file: " + infile$)
  res.q = FileSize(infile$);
  Debug(res)
  If res = -1
    MessageRequester("Error", "The input file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2
    MessageRequester("Error", "The input file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  outfile$ = GetGadgetText(outputFile)
  If outfile$
    res2.q = FileSize(outfile$); ; Check If the output file exists
    Debug(res2)
    If res2 > 0
      result = MessageRequester("Error", "The output file already exists, overwrite?", #PB_MessageRequester_Warning | #PB_MessageRequester_YesNo)
      If result = #PB_MessageRequester_No
        ProcedureReturn
      EndIf
    EndIf
  Else
    MessageRequester("Error", "The output file is empty.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  
  If infile$=outfile$
    MessageRequester("Error", "Input file cannot be the same as output file", #PB_MessageRequester_Error | #PB_MessageRequester_Error)
  EndIf
  
  ; Enable and disable text and button to not run two of ffmpeg at a time
  SetGadgetText(start, "Cancel")
  HideGadget(wait_text, #False)
  
  ; Build ffmpeg argument strings
  state = GetGadgetState(use_advanced)
  If state
    args$ = GetGadgetText(advanced_cmd)
  Else
    args$ = BuildFFmpegArgs()
  EndIf
  args$ = ReplaceString(args$, "{infile}", infile$)
  args$ = ReplaceString(args$, "{outfile}", outfile$)
  Debug(args$)
  
  If Not EnsureFFmpeg(-1)
    SetGadgetText(start, "Reencode")
    HideGadget(wait_text, #True)
    ProcedureReturn
  EndIf
    ; Run ffmpeg
  ffmpeg = RunProgram(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffmpeg.exe", args$, "", #PB_Program_Open | #PB_Program_Read | #PB_Program_Error | #PB_Program_Write | #PB_Program_Hide)
  starttime.q = ElapsedMilliseconds()
  Output$ = ""
  Error$ = ""
  duration.d = 0.0
  If ffmpeg
    Debug("FFmpeg running")
    While ProgramRunning(ffmpeg)
      event = WindowEvent()
      Select event
        Case #PB_Event_Gadget
          Select EventGadget()     
            Case start
              WriteProgramString(ffmpeg, "q")
          EndSelect
      EndSelect
      If AvailableProgramOutput(ffmpeg)
        o$ = ReadProgramString(ffmpeg)
        Debug("Got FFmpeg output line")
        Debug(o$)
        Output$ + o$ + Chr(10)
      EndIf
      e$ = ReadProgramError(ffmpeg)
      extension$=""
      If duration$ = ""
        If CreateRegularExpression(0, "Duration: (\d+:\d{2}:\d{2}\.\d{2})")
          If ExamineRegularExpression(0, e$)
            While NextRegularExpressionMatch(0)
              duration$ = RegularExpressionGroup(0, 1)
              Debug("Duration: " + duration$)
              hours.s     = StringField(duration$, 1, ":")
              minutes.s   = StringField(duration$, 2, ":")
              secFrac.s   = StringField(duration$, 3, ":")
            
              ; Split seconds and hundredths
              seconds.s   = StringField(secFrac, 1, ".")
              hundredths.s= StringField(secFrac, 2, ".")
            
              ; Compute total seconds:
              ; result = hours*3600 + minutes*60 + seconds + hundredths/100
              duration = ValF(hours) * 3600.0 + ValF(minutes) * 60.0 + ValF(seconds) + ValF(hundredths) / 100.0
              Debug(duration)
            Wend
          EndIf
        Else
          Debug(RegularExpressionError())
        EndIf
      EndIf
      
      If LCase(Left(e$, 5)) = "frame"
        time$ = ""
        If CreateRegularExpression(0, "time=(\d+:\d{2}:\d{2}\.\d{2})")
          If ExamineRegularExpression(0, e$)
            While NextRegularExpressionMatch(0)
              time$ = RegularExpressionGroup(0, 1)
              Debug("Time: " + time$)
              hours.s     = StringField(time$, 1, ":")
              minutes.s   = StringField(time$, 2, ":")
              secFrac.s   = StringField(time$, 3, ":")
            
              ; Split seconds and hundredths
              seconds.s   = StringField(secFrac, 1, ".")
              hundredths.s= StringField(secFrac, 2, ".")
            
              ; Compute total seconds:
              ; result = hours*3600 + minutes*60 + seconds + hundredths/100
              time.d = ValF(hours) * 3600.0 + ValF(minutes) * 60.0 + ValF(seconds) + ValF(hundredths) / 100.0
              Debug(time)
              extension$ + "progress=" + InsertString(RSet(Str(Round((time/duration)*10000, #PB_Round_Up)), 4, "0"), ".", 3) + "%"
              
              elapsed.d = (ElapsedMilliseconds() - starttime) / 1000
              Debug("Elapsed: " + elapsed)
              eta.d = elapsed * (duration / time) - elapsed
              Debug("Eta:" + eta)
              extension$ + " eta=" + ConvertSecondsToTimeString(eta)
            Wend
          EndIf
        Else
          Debug(RegularExpressionError())
        EndIf
        Delay(100)
      EndIf
      
      If e$ <> ""
        ;Debug("Got FFmpeg error line")
        Error$ + e$ + Chr(10)
        SetGadgetText(wait_text, e$ + extension$)
      EndIf
    Wend
    
    exitcode = ProgramExitCode(ffmpeg)
    SetGadgetText(wait_text, "Please wait for FFmpeg to finish")
    Debug("FFmpeg exitcode: " + Str(exitcode))
    Debug("-- Stdout --")
    Debug(Output$)
    Debug("------------")
    Debug("-- Stderr --")
    Debug(Error$)
    Debug("------------")
    CloseProgram(ffmpeg)
    If exitcode = 0
      MessageRequester("Information", "FFmpeg is done reencoding.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
    Else
      MessageRequester("Error", ~"FFmpeg failed to convert the video. Check the input (file, resolution, duration, fps) and ouput and try again.\n\n" + Error$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    EndIf
  Else
    MessageRequester("Error", "FFmpeg failed to start.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
  ; Reenable / disable button and text because ffmpeg is done
  SetGadgetText(start, "Reencode")
  HideGadget(wait_text, #True)
  ; Make the main window the current window again, in testing it always vanished into the background for some reason
  SetActiveWindow(Window_0)
EndProcedure

Procedure CheckUpdate(Event)
  Protected fname.s = "CheckUpdate"
  Debug("Running")
  *Buffer = ReceiveHTTPMemory("https://codedancer.de/reencodeffmpeg/files/version")
  If *Buffer
    Size = MemorySize(*Buffer)
    Version = Val(PeekS(*Buffer, Size, #PB_UTF8|#PB_ByteLength))
    Debug("Content: " + Version)
    Debug("CurrentVersion: " + #CurrentVersion)
    Debug(Bool(Version > #CurrentVersion))
    FreeMemory(*Buffer)
    If Version > #CurrentVersion
      result = MessageRequester("Information", "An update is available. Open download page?", #PB_MessageRequester_Info | #PB_MessageRequester_YesNo)
      If result = #PB_MessageRequester_No
        ProcedureReturn
      Else
        RunProgram("https://codedancer.de/reencodeffmpeg/")
      EndIf
    Else
      If Event = -1
      Else
        MessageRequester("Information", "Already on latest version.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
      EndIf
    EndIf
  Else
    Debug("Failed")
    MessageRequester("Error", "Failed to check for updates", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf

EndProcedure

Procedure GetResolution(Event)
  Protected fname.s = "GetResolution"
  Debug("Running")
  file$ = GetGadgetText(inputFile)
  If Not EnsureFFmpeg(-1)
    ProcedureReturn
  EndIf
  Debug("Input file: " + file$)
  res.q = FileSize(file$);
  Debug(res)
  If res = -1
    MessageRequester("Error", "The input file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2
    MessageRequester("Error", "The input file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  
  ffprobe = RunProgram(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffprobe.exe", ~"-v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 \"" + file$ + ~"\"", GetPathPart(file$), #PB_Program_Open | #PB_Program_Read | #PB_Program_Error | #PB_Program_Hide)
  Output$ = ""
  Error$ = ""
  If ffprobe
    Debug("FFprobe running")
    While ProgramRunning(ffprobe)
      WindowEvent()
      o$ = ""
      If AvailableProgramOutput(ffprobe)
        o$ = ReadProgramString(ffprobe)
      EndIf
      e$ = ReadProgramError(ffprobe)
      If o$ <> ""
        Debug("Got FFprobe output line")
        Output$ + o$ + Chr(10)
      EndIf
      If e$ <> ""
        Debug("Got FFprobe error line")
        Error$ + e$ + Chr(10)
      EndIf
    Wend
    
    exitcode = ProgramExitCode(ffprobe)
    Debug("FFprobe exitcode: " + Str(exitcode))
    Debug("-- Stdout --")
    Debug(Output$)
    Debug("------------")
    Debug("-- Stderr --")
    Debug(Error$)
    Debug("------------")
    CloseProgram(ffprobe)
    If Not exitcode=0
      MessageRequester("Error", ~"FFprobe exited with non-zero exitcode. Error:\n\n" + Error$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn
    EndIf
    Output$ = StringField(Output$, 1, ~"\n")
    Debug(Output$)
    Debug("Parsing")
    Debug(StringField(Output$, 1, ","))
    Debug(StringField(Output$, 2, ","))
    SetGadgetAttribute(width_spin, #PB_Spin_Maximum, Val(StringField(Output$, 1, ",")))
    SetGadgetAttribute(height_spin, #PB_Spin_Maximum, Val(StringField(Output$, 2, ",")))
    SetGadgetState(width_spin, Val(StringField(Output$, 1, ",")))
    SetGadgetState(height_spin, Val(StringField(Output$, 2, ",")))
    SetGadgetText(width_spin, StringField(Output$, 1, ","))
    SetGadgetText(height_spin, StringField(Output$, 2, ","))
  Else
    MessageRequester("Error", "FFprobe failed to start.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
  Debug(Output$)
  
EndProcedure

Procedure HelpResolution(Event)
  Protected fname.s = "HelpResolution"
  Debug("Running")
  MessageRequester("Help", ~"With this section you can resize the video.\nClicking on \"Get Resolution\" reads the resolution of the input file and fills it into the respective boxes (Requires FFprobe!)\n\nBy entering -1 into one of the boxes the aspect ratio gets preserved. (For example when having a video in 1920x1080 and entering -1 and 720 it gets resized to 1280x720)\nEntering -1 into both boxes disables resizing.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure HelpFps(Event)
  Protected fname.s = "HelpFps"
  Debug("Running")
  MessageRequester("Help", ~"With this section you can change frame rate the video (Amount of frames per second).\nClicking on \"Get FPS\" reads the frame rate of the input file and fills it into the respective box (Requires FFprobe!)\n\nBy entering -1 into the box the frame rate will not be changed.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure HelpAdvanced(Event)
  Protected fname.s = "HelpAdvanced"
  Debug("Running")
  MessageRequester("Help", ~"When enabling the checkbox, the arguments that FFmpeg would be run with will be generated and put into the text box below to enable customization. If the checkbox is enabled when clicking on \"Reencode\", these custom arguments will be used.\n\n\"{infile}\" will be replaced by the input file.\n\"{outfile}\" will be replaced by the output file.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure HelpCut(Event)
  Protected fname.s = "HelpCut"
  Debug("Running")
  MessageRequester("Help", ~"With this section you can cut the video.\n\nInput the start from where you want the new video to begin as either the number of seconds since the beginning of the original or in the following format:\nHH:MM:SS.xxx\n(H: Hours, M: Minutes, S: Seconds, X: Milliseconds; H, M and S have to be two digits)\n(For example: 01:56:03.555 is a valid format, 1:32.3 not)\n\nThe end of the new video supports the same format and references the point of time in the original video where the new one should end.\n\nThe duration also supports both time in seconds and timestamp as its format.\n\nYou can select only either duration or end of the new video.\n\nIf either value is -1 the video will not be cut.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure.f EvalSimple(expr.s)
  Protected opPos.i
  Protected op$    ; the operator as string
  Protected lhs.s, rhs.s
  
  ; 1) Find the operator position
  For i = 1 To Len(expr.s)
    Select Mid(expr.s, i, 1)
      Case "+"
      Case "-"
      Case "*"
      Case "/"
        opPos = i
        op$    = Mid(expr.s, i, 1)
        Break
    EndSelect
  Next
  
  ; 2) Split into left and right operands
  lhs$ = Trim(Left(expr.s,  opPos - 1))
  rhs$ = Trim(Mid(expr.s,  opPos + 1))
  
  ; 3) Convert to float and compute
  Select op$
    Case "+"  : ProcedureReturn ValF(lhs$) + ValF(rhs$)
    Case "-"  : ProcedureReturn ValF(lhs$) - ValF(rhs$)
    Case "*"  : ProcedureReturn ValF(lhs$) * ValF(rhs$)
    Case "/"  : ProcedureReturn ValF(lhs$) / ValF(rhs$)
  EndSelect
  
  ; if we get here, something went wrong
  ProcedureReturn 0.0
EndProcedure

Procedure GetFps(Event)
  Protected fname.s = "GetFps"
  Debug("Running")
  file$ = GetGadgetText(inputFile)
  If Not EnsureFFmpeg(-1)
    ProcedureReturn
  EndIf
  Debug("Input file: " + file$)
  res.q = FileSize(file$);
  Debug(res)
  If res = -1
    MessageRequester("Error", "The input file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2
    MessageRequester("Error", "The input file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  
  ffprobe = RunProgram(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffprobe.exe", ~"-v error -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate \"" + file$ + ~"\"", GetPathPart(file$), #PB_Program_Open | #PB_Program_Read | #PB_Program_Error | #PB_Program_Hide)
  Output$ = ""
  Error$ = ""
  If ffprobe
    Debug("FFprobe running")
    While ProgramRunning(ffprobe)
      WindowEvent()
      o$ = ""
      If AvailableProgramOutput(ffprobe)
        o$ = ReadProgramString(ffprobe)
      EndIf
      e$ = ReadProgramError(ffprobe)
      If o$ <> ""
        Debug("Got FFprobe output line")
        Output$ + o$ + Chr(10)
      EndIf
      If e$ <> ""
        Debug("Got FFprobe error line")
        Error$ + e$ + Chr(10)
      EndIf
    Wend
    
    exitcode = ProgramExitCode(ffprobe)
    Debug("FFprobe exitcode: " + Str(exitcode))
    Debug("-- Stdout --")
    Debug(Output$)
    Debug("------------")
    Debug("-- Stderr --")
    Debug(Error$)
    Debug("------------")
    CloseProgram(ffprobe)
    If Not exitcode=0
      MessageRequester("Error", ~"FFprobe exited with non-zero exitcode. Error:\n\n" + Error$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn
    EndIf
    
    SetGadgetAttribute(fps_spin, #PB_Spin_Maximum, EvalSimple(Output$))
    SetGadgetState(fps_spin, EvalSimple(Output$))
    SetGadgetText(fps_spin, Str(EvalSimple(Output$)))
    
  Else
    MessageRequester("Error", "FFprobe failed to start.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
EndProcedure

Procedure GetDuration(Event)
  Protected fname.s = "GetDuration"
  Debug("Running")
  file$ = GetGadgetText(inputFile)
  If Not EnsureFFmpeg(-1)
    ProcedureReturn
  EndIf
  Debug("Input file: " + file$)
  res.q = FileSize(file$);
  Debug(res)
  If res = -1
    MessageRequester("Error", "The input file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2
    MessageRequester("Error", "The input file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  
  ffprobe = RunProgram(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffprobe.exe", ~"-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"" + file$ + ~"\"", GetPathPart(file$), #PB_Program_Open | #PB_Program_Read | #PB_Program_Error | #PB_Program_Hide)
  Output$ = ""
  Error$ = ""
  If ffprobe
    Debug("FFprobe running")
    While ProgramRunning(ffprobe)
      WindowEvent()
      o$ = ""
      If AvailableProgramOutput(ffprobe)
        o$ = ReadProgramString(ffprobe)
      EndIf
      e$ = ReadProgramError(ffprobe)
      If o$ <> ""
        Debug("Got FFprobe output line")
        Output$ + o$ + Chr(10)
      EndIf
      If e$ <> ""
        Debug("Got FFprobe error line")
        Error$ + e$ + Chr(10)
      EndIf
    Wend
    
    exitcode = ProgramExitCode(ffprobe)
    Debug("FFprobe exitcode: " + Str(exitcode))
    Debug("-- Stdout --")
    Debug(Output$)
    Debug("------------")
    Debug("-- Stderr --")
    Debug(Error$)
    Debug("------------")
    CloseProgram(ffprobe)
    If Not exitcode=0
      MessageRequester("Error", ~"FFprobe exited with non-zero exitcode. Error:\n\n" + Error$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn
    EndIf
    
    SetGadgetAttribute(start_spin, #PB_Spin_Maximum, Val(Output$))
    SetGadgetAttribute(duration_spin, #PB_Spin_Maximum, Val(Output$))
    SetGadgetState(duration_spin, Val(Output$))
    SetGadgetText(duration_spin, Output$)
    SetGadgetState(start_spin, 0)
    SetGadgetText(start_spin, "0")
    
  Else
    MessageRequester("Error", "FFprobe failed to start.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
EndProcedure

Procedure ToggleAdvanced(Event)
  Protected fname.s = "ToggleAdvanced"
  Debug("Running")
  state = GetGadgetState(use_advanced)
  If state
    MessageRequester("Warning", "Use this only if you know what you are doing. Wrong inputs may break the video files.", #PB_MessageRequester_Warning | #PB_MessageRequester_Ok)
    SetGadgetText(advanced_cmd, BuildFFmpegArgs())
  EndIf
  DisableGadget(advanced_cmd, Bool(Not state))
  DisableGadget(normalize, state)
  DisableGadget(ultrafast, state)
  DisableGadget(superfast, state)
  DisableGadget(veryfast, state)
  DisableGadget(faster, state)
  DisableGadget(fast, state)
  DisableGadget(medium, state)
  DisableGadget(slow, state)
  DisableGadget(slower, state)
  DisableGadget(veryslow, state)
  DisableGadget(height_spin, state)
  DisableGadget(width_spin, state)
  DisableGadget(getResolution, state)
  DisableGadget(res_help, state)
  DisableGadget(fps_spin, state)
  DisableGadget(getFps, state)
  DisableGadget(fps_help, state)
  DisableGadget(duration_spin, state)
  DisableGadget(start_spin, state)
  DisableGadget(getDuration, state)
  DisableGadget(cut_help, state)
  DisableGadget(select_end, state)
  DisableGadget(select_duration, state)
EndProcedure

LoadConfigFile(ConfigFile)

If GetConfigValue("autoCheckUpdate", "notexisting") = "notexisting"
  res = MessageRequester("Update", "Should we automatically check for updates on start?", #PB_MessageRequester_Warning | #PB_MessageRequester_YesNo)
  Config("autoCheckUpdate") = Str(Bool(res = #PB_MessageRequester_Yes))
EndIf
SaveConfigFile(ConfigFile)

If GetConfigValue("autoCheckUpdate", "0") = "1"
  CheckUpdate(-1)
EndIf
;GetResolution()
;GetDuration()
; The main event loop as usual
Repeat
  Event = WaitWindowEvent()
  
  Select EventWindow() ; Select for the Window in which the event happend, incase you have multiple windows
    Case Window_0
      Window_0_Events(Event) ; This procedure name is always window name followed by '_Events'
     
  EndSelect
  
Until Event = #PB_Event_CloseWindow ; Quit on any window close
; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 583
; FirstLine = 447
; Folding = Beug0
; EnableXP
; DPIAware