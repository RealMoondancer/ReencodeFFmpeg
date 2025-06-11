XIncludeFile "ReencodeFfmpeg.pbf" ; Put code from ReencodeFfmpeg.pbf here during compilation (from Form Editor)

#CurrentVersion = 3

OpenWindow_0() ; Start and initialize Window
HideGadget(wait_text, #True) ; Hide the Please wait text
HideGadget(download_text, #True)

Procedure SelectInput(EventType) ; Open a select Dialouge
  Debug "Select Input"
  file$ = OpenFileRequester("Select input file", "", "Video Files|*.webm;*.mkv;*.flv;*.vob;*.ogv;*.ogg;*.drc;*.gif;*.gifv;*.mng;*.avi;*.mts;*.m2ts;*.ts;*.mov;*.qt;*.wmv;*.yuv;*.rm;*.rmvb;*.viv;*.asf;*.amv;*.mp4;*.m4p;*.m4v;*.mpg;*.mp2;*.mpeg;*.mpe;*.mpv;*.m2v;*.m4v;*.svi;*.3gp;*.3g2;*.mxf;*.roq;*.nsv;*.flv;*.f4v;*.f4p;*.f4a;*.f4b", 0)
  If file$ ; If file$   -> A file was selected and not clicked on cancel
  Else
    Debug "No file selected"
    ProcedureReturn
  EndIf
  
  res.q = FileSize(file$) ; Check if the file exists by checking its size
  Debug res;
  If res = -1 ; File not Found
    MessageRequester("Error", "The selected file couldn't be found.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  ElseIf res = -2 ; File is directory
    MessageRequester("Error", "The selected file is a folder.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
    ProcedureReturn
  EndIf
  Debug "Setting in to " + file$
  SetGadgetText(inputFile, file$) ; Set text of input field to selected file
EndProcedure

Procedure SelectOutput(EventType) ; Open a select dialouge
  Debug "Select Output"
  in$ = GetGadgetText(inputFile) ; Get the path of the selected input file to make this the preselected file in the save dialouge
  Debug "Intext: " + in$
  
  file$ = SaveFileRequester("Select output file", in$, "Video Files|*.webm;*.mkv;*.flv;*.vob;*.ogv;*.ogg;*.drc;*.gif;*.gifv;*.mng;*.avi;*.mts;*.m2ts;*.ts;*.mov;*.qt;*.wmv;*.yuv;*.rm;*.rmvb;*.viv;*.asf;*.amv;*.mp4;*.m4p;*.m4v;*.mpg;*.mp2;*.mpeg;*.mpe;*.mpv;*.m2v;*.m4v;*.svi;*.3gp;*.3g2;*.mxf;*.roq;*.nsv;*.flv;*.f4v;*.f4p;*.f4a;*.f4b", 0)
  If file$
  Else
    Debug "No file selected"
    ProcedureReturn
  EndIf
  Debug "Setting out to " + file$
  SetGadgetText(outputFile, file$)
EndProcedure

Procedure RemoveFFmpeg(Event)
  If DeleteFile(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffmpeg.exe")
    MessageRequester("Information", "Successfully deleted FFmpeg", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
  Else
    MessageRequester("Error", "Failed to delete FFmpeg", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
EndProcedure

Procedure EnsureFFmpeg()
  Debug "Checking FFmpeg"
  ffpath$ = GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\"
  Debug ffpath$
  res.q = FileSize(ffpath$)
  If res = -1
    Debug "Directory doesn't exist, creating..."
    result = CreateDirectory(ffpath$)
    If result = 0
      MessageRequester("Error", "Failed to create " + ffpath$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn #False
    EndIf
  EndIf
  ffpath$ = ffpath$ + "ffmpeg.exe"
  Debug "Checking " + ffpath$
  res.q = FileSize(ffpath$)
  If res = -1
    ; Get File size
    HttpRequest = HTTPRequest(#PB_HTTP_Get, "https://www.codedancer.de/reencodeffmpeg/files/ffmpeg.exe", "", #PB_HTTP_HeadersOnly)
    Debug "Response: " + HTTPInfo(HTTPRequest, #PB_HTTP_Response)
    Debug "StatusCode: " + HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode)
    headers$ = HTTPInfo(HTTPRequest, #PB_HTTP_Headers)
    Debug "Headers: " + headers$
    FinishHTTP(HTTPRequest)
    ContentSize = 1
    If CreateRegularExpression(0, "^[\w\W]*Content-Length: (\d+)[\w\W]*$")
      If ExamineRegularExpression(0, headers$)
      While NextRegularExpressionMatch(0)
        ContentSize = Val(RegularExpressionGroup(0, 1))
        Debug "Size is " + ContentSize
      Wend
    EndIf

    Else
      Debug RegularExpressionError()
    EndIf
    Debug "Doesn't exist, trying to download"
    result = MessageRequester("Error", ~"FFmpeg couldn't be found. Download automatically?\n\nIt will be saved to\n" + ffpath$, #PB_MessageRequester_Warning | #PB_MessageRequester_YesNo)
    If result = #PB_MessageRequester_No
      ProcedureReturn #False
    EndIf
    Download = ReceiveHTTPFile("https://www.codedancer.de/reencodeffmpeg/files/ffmpeg.exe", ffpath$, #PB_HTTP_Asynchronous)
    If Download
      HideGadget(download_text, #False)
      Repeat
        Progress = HTTPProgress(Download)
        Select Progress
          Case #PB_HTTP_Success
            Size = FinishHTTP(Download)
            Debug "Download finished (size: " + size + ")"
            MessageRequester("Information", "FFmpeg successfully downloaded", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
            HideGadget(download_text, #True)
            ProcedureReturn #True
  
          Case #PB_HTTP_Failed
            Debug "Download failed"
            FinishHTTP(Download)
            MessageRequester("Error", ~"FFmpeg download failed, please try again later or save it manually at\n" + ffpath$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
            HideGadget(download_text, #True)
            ProcedureReturn #False
  
          Case #PB_HTTP_Aborted
            Debug "Download aborted"
            FinishHTTP(Download)
            MessageRequester("Error", ~"FFmpeg download aborted, please try again later or save it manually at\n" + ffpath$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
            HideGadget(download_text, #True)
            ProcedureReturn #False
            
          Default
            prg.d = Round((Progress/ContentSize)*10000, #PB_Round_Up) / 100 ; xx.xx% cap to 2 digits after .
            SetGadgetText(download_text, "Downloading FFmpeg: " + prg + "% (" + Progress + "/" + ContentSize + ")")
            WindowEvent()
         
        EndSelect
        
        Delay(100) ; Don't stole the whole CPU
      ForEver
        
    Else
      MessageRequester("Error", ~"FFmpeg couldn't be downloaded. Please download it manually and save it at\n" + ffpath$, #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
      ProcedureReturn #False
    EndIf
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure About(Event)
  MessageRequester("About", ~"(c) 2025 Moondancer Productions (Ditin2)\n\nMade using PureBasic 6.20 and FFmpeg 2025-05-26-git-43a69886b2-essentials_build-www.gyan.dev", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure PCRELicense(Event)
  MessageRequester("PCRE License", ~"PCRE LICENCE\n------------\n\nPCRE is a library of functions To support regular expressions whose syntax\nand semantics are As close As possible To those of the Perl 5 language.\n\nRelease 7 of PCRE is distributed under the terms of the \"BSD\" licence, As\nspecified below. The documentation For PCRE, supplied in the \"doc\"\ndirectory, is distributed under the same terms As the software itself.\n\nThe basic library functions are written in C And are freestanding. Also\nincluded in the distribution is a set of C++ wrapper functions.\n\n\nTHE BASIC LIBRARY FUNCTIONS\n---------------------------\n\nWritten by:       Philip Hazel\nEmail local part: ph10\nEmail domain:     cam.ac.uk\n\nUniversity of Cambridge Computing Service,\nCambridge, England.\n\nCopyright (c) 1997-2007 University of Cambridge\nAll rights reserved.\n\n\nTHE C++ WRAPPER FUNCTIONS\n-------------------------\n\nContributed by:   Google Inc.\n\nCopyright (c) 2007, Google Inc.\nAll rights reserved.\n\n\nTHE \"BSD\" LICENCE\n-----------------\n\nRedistribution And use in source And binary forms, With Or without\nmodification, are permitted provided that the following conditions are met:\n\n    * Redistributions of source code must retain the above copyright notice,\n      this List of conditions And the following disclaimer.\n\n    * Redistributions in binary form must reproduce the above copyright\n      notice, this List of conditions And the following disclaimer in the\n      documentation And/Or other materials provided With the distribution.\n\n    * Neither the name of the University of Cambridge nor the name of Google\n      Inc. nor the names of their contributors may be used To endorse Or\n      promote products derived from this software without specific prior\n      written permission.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS And CONTRIBUTORS \"As IS\"\nAND ANY EXPRESS Or IMPLIED WARRANTIES, INCLUDING, BUT Not LIMITED To, THE\nIMPLIED WARRANTIES OF MERCHANTABILITY And FITNESS For A PARTICULAR PURPOSE\nARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER Or CONTRIBUTORS BE\nLIABLE For ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, Or\nCONSEQUENTIAL DAMAGES (INCLUDING, BUT Not LIMITED To, PROCUREMENT OF\nSUBSTITUTE GOODS Or SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS\nINTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN\nCONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)\nARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE\nPOSSIBILITY OF SUCH DAMAGE.\n\nEnd", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
EndProcedure

Procedure StartReencode(EventType)
  Debug "Start Reencode event"
  Debug "Normalize audio: " + GetGadgetState(normalize)
  infile$ = GetGadgetText(inputFile) ; Same stuff as in SelectInput()
  Debug "Input file: " + infile$
  res.q = FileSize(infile$);
  Debug res;
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
    Debug res2;
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
  
  
  EnsureFFmpeg()
  
  ; Enable and disable text and button to not run two of ffmpeg at a time
  DisableGadget(start, #True)
  HideGadget(wait_text, #False)
  
  ; Build ffmpeg argument strings
  filters$ = ""
  preset$= ""
  Define.s quote = Chr(34)
  If GetGadgetState(normalize)
    ; If normalize is checked, add the audio filter
    filters$ = "-filter:a " + quote + "dynaudnorm=p=0.9:s=5" + quote + " "
  EndIf
  
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
  
  If Not EnsureFFmpeg()
    DisableGadget(start, #False)
    HideGadget(wait_text, #True)
    ProcedureReturn
  EndIf
  MessageRequester("Information", "To cancel/interrupt FFmpeg press Q or Ctrl+C whilst in the FFmpeg Terminal.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
    ; Run ffmpeg
  pid = RunProgram(GetUserDirectory(#PB_Directory_ProgramData) + "ReencodeFfmpeg\ffmpeg.exe", "-y -i " + quote + infile$ + quote + " " + preset$ + filters$ + quote + outfile$ + quote, "", #PB_Program_Wait)
  ;Debug "PID: " + pid
  If pid
    MessageRequester("Information", "FFmpeg is done reencoding.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
  Else
    MessageRequester("Error", "FFmpeg failed to start.", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf
  ; Reenable / disable button and text because ffmpeg is done
  DisableGadget(start, #False)
  HideGadget(wait_text, #True)
  ; Make the main window the current window again, in testing it always vanished into the background for some reason
  SetActiveWindow(Window_0)
EndProcedure

Procedure CheckUpdate(Event)
  *Buffer = ReceiveHTTPMemory("https://codedancer.de/reencodeffmpeg/files/version")
  If *Buffer
    Size = MemorySize(*Buffer)
    Version = Val(PeekS(*Buffer, Size, #PB_UTF8|#PB_ByteLength))
    Debug "Content: " + Version
    Debug "CurrentVersion: " + #CurrentVersion
    Debug Bool(Version > #CurrentVersion)
    FreeMemory(*Buffer)
    If Version > #CurrentVersion
      result = MessageRequester("Information", "An update is available. Open download page?", #PB_MessageRequester_Info | #PB_MessageRequester_YesNo)
      If result = #PB_MessageRequester_No
        ProcedureReturn
      Else
        RunProgram("https://codedancer.de/reencodeffmpeg/")
      EndIf
    Else
      If Event = #Null
      Else
        MessageRequester("Information", "Already on latest version.", #PB_MessageRequester_Info | #PB_MessageRequester_Ok)
      EndIf
    EndIf
  Else
    Debug "Failed"
    MessageRequester("Error", "Failed to check for updates", #PB_MessageRequester_Error | #PB_MessageRequester_Ok)
  EndIf

EndProcedure


CheckUpdate(#Null)
EnsureFFmpeg()
; The main event loop as usual
Repeat
  Event = WaitWindowEvent()
  
  Select EventWindow() ; Select for the Window in which the event happend, incase you have multiple windows
    Case Window_0
      Window_0_Events(Event) ; This procedure name is always window name followed by '_Events'
     
  EndSelect
  
Until Event = #PB_Event_CloseWindow ; Quit on any window close
; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 248
; FirstLine = 203
; Folding = --
; EnableXP
; DPIAware