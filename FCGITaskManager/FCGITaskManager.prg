#xcommand TRY => BEGIN SEQUENCE WITH __BreakBlock()
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xcommand ENDTRY => END
#xcommand ENDDO => END
#xcommand ENDFOR => END

#define CRLF chr(13)+chr(10)

// #xtranslate Allt( <x> )    => alltrim( <x> )
// #xtranslate Trans( <x> )   => alltrim( str(<x>,10) )
 
function Main()
   local cAction
   local cURL
   local cProtocol
   local cPort
   local cDomain
   local cWebsiteFolder
   local cFcgiFolder
   local cExeFileNameRoot
   local cExeFileNameSuffix
   local oScriptObj
   local oWmiService
   local oListOfProcess
   local oProcess
   local cProcessName
   // local cListOfProcessToRemoteKill := ""
   local oHttp
   local oError
   local cConfig
 
   cAction            := upper(hb_argv(1))
   cProtocol          := hb_argv(2)
   cDomain            := hb_argv(3)
   cPort              := hb_argv(4)
   cWebsiteFolder     := hb_argv(5)
   cFcgiFolder        := hb_argv(6)
   cExeFileNameRoot   := hb_argv(7)
   cExeFileNameSuffix := hb_argv(8)

   if empty(cAction)
      ? [Missing "Action"]

   elseif !(cAction == "DOWN" .or. cAction == "ACTIVATE")
      ? ["Action" must be "down" or "activate"]
      cAction := ""

   endif

   if !empty(cAction)
      if !(cProtocol == "http" .or. cProtocol == "https")
         ? ["Protocol" must be "http" or "https"]
         cAction := ""
      elseif empty(cDomain)
         ? [Missing "Domain"]
         cAction := ""
      elseif empty(cPort)
         ? [Missing "Port"]
         cAction := ""
      elseif val(cPort) < 80
         ? ["Port" must be a numeric >= 80]
         cAction := ""
      elseif empty(cWebsiteFolder)
         ? [Missing "WebsiteFolder". Use "/" for root.]
         cAction := ""
      elseif empty(cFcgiFolder)
         ? [Missing "FcgiFolder"]
         cAction := ""
      elseif !hb_DirExists(cFcgiFolder)
         ? [Invalid "FcgiFolder"]
         cAction := ""
      elseif empty(cExeFileNameRoot)
         ? [Missing "ExeFileNameRoot"]
         cAction := ""
      endif
   endif

   if !empty(cAction)
      //Later will try to use curl instead.
      cURL := cProtocol+"://"+cDomain+":"+cPort+cWebsiteFolder

      do case
      case cAction == "DOWN"
         cConfig := 'FallbackResource '+cWebsiteFolder+'down.html' + CRLF
         //On purpose don't force all to down.html, since the ".kill" have to be processed.

      case cAction == "ACTIVATE"
         cConfig := 'FallbackResource '+cWebsiteFolder+cExeFileNameRoot+cExeFileNameSuffix+'.exe' + CRLF
         cConfig += 'FcgidWrapper "'+cFcgiFolder+cExeFileNameRoot+cExeFileNameSuffix+'.exe" .mainexe virtual'
            
      endcase
      hb_MemoWrit(cFcgiFolder+".htaccess",cConfig)
      
      try
         //oHttp := win_oleCreateObject("MSXML2.XMLHTTP.6.0")  This control May cache requests
         oHttp := win_oleCreateObject("MSXML2.ServerXMLHTTP")
      catch oError
         ? [Failed to initilalize HTTP object. Error message: ]+oError:Description
         oHttp := nil
      endtry

      if oHttp <> nil
         try
            oScriptObj     := win_OleCreateObject([wbemScripting.SwbemLocator])
            oWmiService    := oScriptObj:ConnectServer()
            oListOfProcess := oWmiService:ExecQuery("select * from Win32_Process")
         catch
            oListOfProcess := {}
         endtry
   
         for each oProcess in oListOfProcess
            cProcessName := oProcess:Name()
            if upper(left(cProcessName,len(cExeFileNameRoot))) <> upper(cExeFileNameRoot)
               loop
            endif
            if lower(right(cProcessName,4)) == ".exe"
               cProcessName := left(cProcessName,len(cProcessName)-4)
            endif
            
            if cAction == "ACTIVATE"
               if lower(cProcessName) == lower(cExeFileNameRoot+cExeFileNameSuffix)
                  loop
               endif
            endif

            if !file(cFcgiFolder+cProcessName+".kill")
               hb_MemoWrit(cFcgiFolder+cProcessName+".kill","ShutdownMarker")
            endif

            // altd()
            try
               oHttp:Open( "GET", cURL+cProcessName+".kill", .f. )   // .f. = Synchronous
               oHttp:Send()
            catch oError
               ? [Failed to execute HTTP GET. Error message: ]+oError:Description
               loop
            endtry

            //Maybe Add logic to repeat this multiple time, until all exe instances are do and could delete the exe, EXCEPT if the exe ends with the suffix
            // cListOfProcessToRemoteKill += cProcessName + CRLF

         endfor

         oHttp := nil

         do case
         case cAction == "DOWN"
            cConfig := 'RewriteRule "^" "'+cURL+'down.html" [END]'
            //Add logic to create any missing ".kill" files, since not all the older versions might have been running.
         case cAction == "ACTIVATE"
            //Blindly try to delete the .kill marker file
            DeleteFile(cFcgiFolder+cExeFileNameRoot+cExeFileNameSuffix+".kill")
         endcase
         hb_MemoWrit(cFcgiFolder+".htaccess",cConfig)
   
      endif

   endif


   // SendToClipboard(cListOfProcessToRemoteKill)
   // Altd()

  
return nil
//=================================================================================================================
function SendToClipboard(cText)
   wvt_SetClipboard(cText)
return .T.
//=================================================================================================================
