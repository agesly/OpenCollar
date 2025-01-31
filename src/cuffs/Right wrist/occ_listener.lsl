////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            occ_listener                                        //
//                            version 7.1                                         //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2018  OpenNC                                                        //
// ©   2018 -       North Glenwalker and OpenCollar                               //
////////////////////////////////////////////////////////////////////////////////////

integer g_iListenChan = 1;
integer g_iListenChan0 = TRUE;
string g_sPrefix = ".";
integer g_iListener1;
integer g_iListener2;
integer CUFF_CHANNEL;
integer COLLAR_CHANNEL;
integer SYNC = TRUE;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_COLLAR = 499;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer NOTIFY = 550;
integer POPUP_HELP = 1001;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to settings store
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
string g_sSafeWord = "RED";
//added for attachment auth
integer g_iInterfaceChannel = -12587429;
integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC; // offset to be used to make sure we do not interfere with other items using the same technique for
integer g_iListenHandleAtt;
integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
integer ATTACHMENT_FORWARD = 610;
key g_kWearer;
string g_sSeparator = "|";
string g_iAuth;
string UUID;
string g_sCmd;

integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;//normal collar/cuff channel
    if (iChan>0)
        iChan=iChan*(-1);
    if (iChan > -10000)
        iChan -= 30000; //so when we add 1 to it we are still on separate channel to collar.
    return iChan;
}

SetListeners()
{
    CUFF_CHANNEL = GetOwnerChannel(g_kWearer, 1110); //Normal cuff channel = collar channel +1
    COLLAR_CHANNEL = GetOwnerChannel(g_kWearer, 1111); //Normal collar channel
    llListenRemove(CUFF_CHANNEL);
    llListenRemove(COLLAR_CHANNEL);
    llListenRemove(g_iListener1);
    llListenRemove(g_iListener2);
    llListenRemove(g_iListenHandleAtt);
    if(g_iListenChan0 == TRUE)
        g_iListener1 = llListen(0, "", "", "");
    g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
    if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
    g_iListenHandleAtt = llListen(g_iInterfaceChannel, "", "", "");
    g_iListener2 = llListen(g_iListenChan, "", "", "");
    llListen(CUFF_CHANNEL, "", "", "");//Listen to external Objects here
    llListen(COLLAR_CHANNEL, "", "", "");//Listen to Our Collar here
}

string AutoPrefix()
{
    list sName = llParseString2List(llKey2Name(g_kWearer), [" "], []);
    return llToLower(llGetSubString(llList2String(sName, 0), 0, 1));
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    //Ilse: blame/applaud Strife Onizuka for this godawfully ugly though apparently optimized function
    integer iLen = (~-(llStringLength(sFrom)));
    if(~iLen)
    {
        string  sBuffer = sSrc;
        integer iBufPos = -1;
        integer iToLen = (~-(llStringLength(sTo)));
        @loop;//instead of a while loop, saves 5 bytes (and run faster).
        integer iToPos = ~llSubStringIndex(sBuffer, sFrom);
        if(iToPos)
        {
            iBufPos -= iToPos;
            sSrc = llInsertString(llDeleteSubString(sSrc, iBufPos, iBufPos + iLen), iBufPos, sTo);
            iBufPos += iToLen;
            sBuffer = llGetSubString(sSrc, (-~(iBufPos)), 0x8000);
            jump loop;
        }
    }
    return sSrc;
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

Notify(key kID, string sMsg, string iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
        llOwnerSay(sMsg);
    else
    {
        if (llGetAgentSize(kID) != ZERO_VECTOR)
            llRegionSayTo(kID,0,sMsg);
        else
            llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer == "TRUE")
            llOwnerSay(sMsg);
    }
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        g_sPrefix = AutoPrefix();
        SetListeners();
    }

    listen(integer sChan, string sName, key kID, string sMsg)
    {
        // new object/HUD channel block
         if((kID == g_kWearer) && ((sMsg == g_sSafeWord)||(sMsg == "(("+g_sSafeWord+"))")))
        { // safeword can be the safeword or safeword said in OOC chat "((SAFEWORD))"
            llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", "");
            llOwnerSay("You used your safeword, your owner will be notified you did.");
        }
        if (sChan == CUFF_CHANNEL)//send everything for checking this should all come from the collar
        {//llOwnerSay(sMsg);
            list lParams = llParseString2List(sMsg, [":"], []);
            integer i = llGetListLength(lParams);
            key kTouch = (key)llList2String(lParams, 0);
            sMsg = llList2String(lParams, 1);
            if (kTouch)
            {
                string out = llDumpList2String([sMsg], "|");
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, out, llGetOwnerKey(kID));//send to auth to check
//                llOwnerSay(out);
            }
            else //this should never happen
                Notify(kID, "Syntax Error! Request must be <uuid>:<command>", "FALSE");
        }
        else if (sChan == g_iInterfaceChannel)
        {
            //do nothing if wearer isnt owner of the object
            if (llGetOwnerKey(kID) != g_kWearer)
                return;
            integer iIndex = llSubStringIndex(sMsg, g_sSeparator);
            g_iAuth = llGetSubString(sMsg, 0, iIndex - 1);
            if (g_iAuth == "0") //auth request
            {
                g_sCmd = llGetSubString(sMsg, iIndex + 1, -1);
                iIndex = llSubStringIndex(g_sCmd, g_sSeparator);
                UUID = llGetSubString(g_sCmd, iIndex + 1, llStringLength(sMsg) - 40);
    //just send ATTACHMENT_REQUEST and ID to auth, as no script IN the cuffs needs the command anyway
                llMessageLinked(LINK_SET, ATTACHMENT_REQUEST, "", (key)UUID);
            }
            else if (g_iAuth == (string)COMMAND_COLLAR) //command from attachment to AO
                llWhisper(g_iInterfaceChannel, sMsg);
            else // we received a unkown command, so we just forward it via LM into the cuffs
                llMessageLinked(LINK_SET, ATTACHMENT_FORWARD, sMsg, kID);
        }
        else
        { //check for our prefix, or *
            if (StartsWith(sMsg, g_sPrefix + "c"))
            { //trim
                sMsg = llGetSubString(sMsg, llStringLength(g_sPrefix) +1, -1); //+1 to remove the "c"
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            else if (llGetSubString(sMsg, 0, 1) == "*c")
            {
                sMsg = llGetSubString(sMsg, 2, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            // added # as prefix for all subs around BUT yourself
            else if ((llGetSubString(sMsg, 0, 1) == "#c") && (kID != g_kWearer))
            {
                sMsg = llGetSubString(sMsg, 2, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParam1 = llParseString2List(sStr, ["_"], []);
            string str1b= llList2String(lParam1, 0);
            if(str1b == "color" || str1b == "texture" ||str1b == "glow" || str1b == "shiny" || sStr == "show" || sStr == "hide")//from themes and stealth
            {
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, sStr , "");
                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, sStr , "");
            }
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            list lParams1 = llParseString2List(sStr, ["="], []);
            string str1a = llToLower(llList2String(lParams1, 0));
            if(str1a=="intern_dist" || str1a == "auth_owner" || str1a == "tempowner" || str1a == "auth_trust" || str1a == "auth_block" || str1a == "auth_public" || str1a == "auth_group")//update our auth list
            {
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, sStr, "");
                llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, sStr , "");
            }
            if (sStr == "settings")// answer for settings command
            {
                Notify(kID,"prefix: " + g_sPrefix, "FALSE");
                Notify(kID,"channel: " + (string)g_iListenChan,"FALSE");
            }
            else if (sStr == "ping")// ping from an object, we answer to it on the object channel
                llRegionSayTo(g_kWearer,COLLAR_CHANNEL,(string)g_kWearer+":pong");
            else if (iNum == COMMAND_OWNER)//handle changing prefix and channel from owner/not sure we need this here now?????
            {
                if (sCommand == "prefix")
                {
                    string sNewPrefix = llList2String(lParams, 1);
                    if (sNewPrefix == "auto")
                        g_sPrefix = AutoPrefix();
                    else if (sNewPrefix != "")
                        g_sPrefix = sNewPrefix;
                    SetListeners();
                    Notify(kID, "\n" + llKey2Name(g_kWearer) + "'s prefix is '" + g_sPrefix + "'.\nTouch the cuffs or say '" + g_sPrefix + "cmenu' for the main menu.\nSay '" + g_sPrefix + "help' for a list of chat commands.", "FALSE");
                }
                else if (sCommand == "channel")
                {
                    integer iNewChan = (integer)llList2String(lParams, 1);
                    if (iNewChan > 0)
                    {
                        g_iListenChan =  iNewChan;
                        SetListeners();
                        Notify(kID, "Now listening on channel " + (string)g_iListenChan + ".", "FALSE");
                    }
                    else if (iNewChan == 0)
                    {
                        g_iListenChan0 = TRUE;
                        SetListeners();
                        Notify(kID, "You enabled the public channel listener.\nTo disable it use -1 as channel command.", "FALSE");
                    }
                    else if (iNewChan == -1)
                    {
                        g_iListenChan0 = FALSE;
                        SetListeners();
                        Notify(kID, "You disabled the public channel listener.\nTo enable it use 0 as channel command, remember you have to do this on your channel /" +(string)g_iListenChan, "FALSE");
                    }
                }
            }
            if (kID == g_kWearer)
            {
                if (sCommand == "safeword")
                {   // new for safeword
                    if(llStringTrim(sValue, STRING_TRIM) != "")
                    {
                        g_sSafeWord = llList2String(lParams, 1);
                        llOwnerSay("You set a new safeword: " + g_sSafeWord + ".");
                    }
                    else
                        llOwnerSay("Your safeword is: " + g_sSafeWord + ".");
                }
                else if (sStr == g_sSafeWord)
                { //safeword used with prefix
                    llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", "");
                    llOwnerSay("You used your safeword, your owner will be notified you did.");
                }
                else
                {
                    list lParam = llParseString2List(sStr, ["|"], []);
                    integer h = llGetListLength(lParam);
                    string str1= llList2String(lParam, 0);
                    key kAv = (key)llList2String(lParam, 1);
                    if(kAv != "") llMessageLinked (LINK_SET, COMMAND_NOAUTH, str1, kAv);
                }
            }
        }
        else if (iNum == NOTIFY)
        {
            list lParams = llParseString2List(sStr, ["|"], []);
            integer i = llGetListLength(lParams);
            string msg1 = llList2String(lParams, 0);
            string msg2 = llList2String(lParams, 1);
            Notify(kID, msg1, msg2);
        }
        else if (iNum == POPUP_HELP)
        { //replace _PREFIX_ with prefix, and _CHANNEL_ with (string) channel
            sStr = StringReplace(sStr, "_PREFIX_", g_sPrefix);
            sStr = StringReplace(sStr, "_CHANNEL_", (string)g_iListenChan);
            Notify(kID, sStr, "FALSE");
        }
        else if (iNum == ATTACHMENT_RESPONSE)
        {
            //here the response from auth has to be:
            // llMessageLinked(LINK_SET, ATTACHMENT_RESPONSE, "auth", UUID);
            //where "auth" has to be (string)COMMAND_XY
            //reason for this is: i dont want to have all other scripts recieve a COMMAND+xy and check further for the command
            llWhisper(g_iInterfaceChannel, "RequestReply|" + sStr + g_sSeparator + g_sCmd);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}